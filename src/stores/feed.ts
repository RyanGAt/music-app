import { defineStore } from 'pinia';
import { supabase } from '../lib/supabase';
import type { Track } from '../lib/musicProvider';
import { audiusProvider } from '../lib/audiusProvider';
import { useAuthStore } from './auth';

export type Post = {
  id: string;
  user_id: string;
  type: 'auto_moment' | 'song_moment' | 'repost';
  source?: string;
  track_id: string | null;
  start_ms: number | null;
  text: string | null;
  original_post_id: string | null;
  created_at: string;
  profiles?: { id: string; display_name: string; avatar_url: string | null } | null;
  original?: Post | null;
  likeCount?: number;
  commentCount?: number;
  recentLikeCount?: number;
  recentCommentCount?: number;
  popularityScore?: number;
};

const MIN_FEED_ITEMS = 50;
const MOMENT_WINDOW_MS = 15000;
const RECENT_WINDOW_MS = 24 * 60 * 60 * 1000;
const DUPLICATE_WINDOW_MS = 6 * 60 * 60 * 1000;

const toTrackCacheRow = (track: Track) => ({
  id: track.id,
  source: 'audius',
  title: track.title,
  artist: track.artist,
  duration_ms: track.duration_ms,
  artwork_url: track.artwork_url ?? null,
  permalink_url: track.permalink_url ?? null,
  stream_url: track.stream_url ?? null,
  last_fetched_at: new Date().toISOString(),
});

export const useFeedStore = defineStore('feed', {
  state: () => ({
    posts: [] as Post[],
    loading: false,
    trackCache: new Map<string, Track>(),
    activePostId: null as string | null,
    likedPostIds: new Set<string>(),
    sortMode: 'latest' as 'latest' | 'popular',
  }),
  actions: {
    async upsertTrackCache(tracks: Track[]) {
      if (tracks.length === 0) return;
      const rows = tracks.map(toTrackCacheRow);
      await supabase.from('tracks_cache').upsert(rows, { onConflict: 'id' });
      rows.forEach((row) => {
        this.trackCache.set(row.id, {
          id: row.id,
          title: row.title,
          artist: row.artist,
          duration_ms: row.duration_ms,
          artwork_url: row.artwork_url ?? undefined,
          permalink_url: row.permalink_url ?? undefined,
          stream_url: row.stream_url ?? undefined,
        });
      });
    },
    async fetchTrack(trackId: string) {
      if (this.trackCache.has(trackId)) return this.trackCache.get(trackId)!;
      const { data: cached } = await supabase
        .from('tracks_cache')
        .select('id, title, artist, duration_ms, artwork_url, permalink_url, stream_url')
        .eq('id', trackId)
        .maybeSingle();

      if (cached) {
        const track: Track = {
          id: cached.id,
          title: cached.title,
          artist: cached.artist,
          duration_ms: cached.duration_ms,
          artwork_url: cached.artwork_url ?? undefined,
          permalink_url: cached.permalink_url ?? undefined,
          stream_url: cached.stream_url ?? undefined,
        };
        this.trackCache.set(trackId, track);
        return track;
      }

      const track = await audiusProvider.getTrack(trackId);
      if (!track) throw new Error('Track not found');
      await this.upsertTrackCache([track]);
      return track;
    },
    async loadPosts() {
      const { data: posts, error } = await supabase
        .from('posts')
        .select(
          'id, user_id, type, track_id, start_ms, text, original_post_id, created_at',
        )
        .eq('visibility', 'public')
        .eq('type', 'auto_moment')
        .order('created_at', { ascending: false })
        .limit(80);

      if (error) throw error;
      return posts ?? [];
    },
    async ensureAutoMoments(existingCount: number) {
      const auth = useAuthStore();
      const needed = Math.max(0, MIN_FEED_ITEMS - existingCount);
      if (!auth.userId || needed === 0) return;

      let tracks: Track[] = [];
      try {
        tracks = await audiusProvider.getRandomTracks(needed);
      } catch (error) {
        console.warn('Failed to fetch Audius tracks', error);
        return;
      }
      if (tracks.length === 0) return;

      const duplicateCutoff = new Date(Date.now() - DUPLICATE_WINDOW_MS).toISOString();
      const trackIds = tracks.map((track) => track.id);
      const { data: recent } = await supabase
        .from('posts')
        .select('track_id')
        .eq('type', 'auto_moment')
        .gte('created_at', duplicateCutoff)
        .in('track_id', trackIds);

      const recentTrackIds = new Set(recent?.map((row) => row.track_id).filter(Boolean) ?? []);
      const uniqueTracks = tracks.filter((track) => !recentTrackIds.has(track.id));
      if (uniqueTracks.length === 0) return;

      const now = new Date().toISOString();
      const inserts = uniqueTracks.map((track) => {
        const maxStart = Math.max(0, track.duration_ms - MOMENT_WINDOW_MS);
        const startMs = maxStart > 0 ? Math.floor(Math.random() * maxStart) : 0;
        return {
          user_id: auth.userId,
          type: 'auto_moment',
          source: 'audius',
          track_id: track.id,
          start_ms: startMs,
          text: null,
          visibility: 'public',
          created_at: now,
        };
      });

      await supabase.from('posts').insert(inserts);
      await this.upsertTrackCache(uniqueTracks);
    },
    sortPosts(posts: Post[]) {
      if (this.sortMode === 'latest') {
        return [...posts].sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at));
      }
      return [...posts].sort(
        (a, b) => (b.popularityScore ?? 0) - (a.popularityScore ?? 0) || Date.parse(b.created_at) - Date.parse(a.created_at),
      );
    },
    calculatePopularityScore(post: Post) {
      const totalLikes = post.likeCount ?? 0;
      const totalComments = post.commentCount ?? 0;
      const recentLikes = post.recentLikeCount ?? 0;
      const recentComments = post.recentCommentCount ?? 0;
      const hasRecent = recentLikes > 0 || recentComments > 0;
      const scoreLikes = hasRecent ? recentLikes : totalLikes;
      const scoreComments = hasRecent ? recentComments : totalComments;
      return scoreLikes * 2 + scoreComments * 3;
    },
    setSortMode(mode: 'latest' | 'popular') {
      this.sortMode = mode;
      this.posts = this.sortPosts(this.posts);
    },
    async fetchFeed() {
      const auth = useAuthStore();
      this.loading = true;

      let posts = await this.loadPosts();
      if (posts.length < MIN_FEED_ITEMS) {
        await this.ensureAutoMoments(posts.length);
        posts = await this.loadPosts();
      }

      const postIds = posts.map((post) => post.id);
      if (postIds.length === 0) {
        this.posts = [];
        this.loading = false;
        return;
      }
      const { data: likes } = await supabase
        .from('likes')
        .select('post_id, user_id, created_at')
        .in('post_id', postIds);
      const { data: comments } = await supabase
        .from('comments')
        .select('post_id, created_at')
        .in('post_id', postIds);
      const { data: userLikes } = await supabase
        .from('likes')
        .select('post_id')
        .eq('user_id', auth.userId)
        .in('post_id', postIds);

      this.likedPostIds = new Set(userLikes?.map((row) => row.post_id) ?? []);

      const likeCounts = new Map<string, number>();
      const recentLikeCounts = new Map<string, number>();
      const recentCutoff = Date.now() - RECENT_WINDOW_MS;
      likes?.forEach((like) => {
        likeCounts.set(like.post_id, (likeCounts.get(like.post_id) ?? 0) + 1);
        if (Date.parse(like.created_at) >= recentCutoff) {
          recentLikeCounts.set(like.post_id, (recentLikeCounts.get(like.post_id) ?? 0) + 1);
        }
      });

      const commentCounts = new Map<string, number>();
      const recentCommentCounts = new Map<string, number>();
      comments?.forEach((comment) => {
        commentCounts.set(comment.post_id, (commentCounts.get(comment.post_id) ?? 0) + 1);
        if (Date.parse(comment.created_at) >= recentCutoff) {
          recentCommentCounts.set(comment.post_id, (recentCommentCounts.get(comment.post_id) ?? 0) + 1);
        }
      });

      const ranked = posts.map((post) => {
        const totalLikes = likeCounts.get(post.id) ?? 0;
        const totalComments = commentCounts.get(post.id) ?? 0;
        const recentLikes = recentLikeCounts.get(post.id) ?? 0;
        const recentComments = recentCommentCounts.get(post.id) ?? 0;
        return {
          ...post,
          likeCount: totalLikes,
          commentCount: totalComments,
          recentLikeCount: recentLikes,
          recentCommentCount: recentComments,
          popularityScore: this.calculatePopularityScore({
            ...post,
            likeCount: totalLikes,
            commentCount: totalComments,
            recentLikeCount: recentLikes,
            recentCommentCount: recentComments,
          }),
        } as Post;
      });

      this.posts = this.sortPosts(ranked);
      this.loading = false;
    },
    async toggleLike(postId: string, isLiked: boolean) {
      const auth = useAuthStore();
      const post = this.posts.find((item) => item.id === postId);
      if (!auth.userId || !post) return;
      const delta = isLiked ? -1 : 1;
      post.likeCount = Math.max(0, (post.likeCount ?? 0) + delta);
      post.recentLikeCount = Math.max(0, (post.recentLikeCount ?? 0) + delta);
      post.popularityScore = this.calculatePopularityScore(post);
      if (isLiked) {
        this.likedPostIds.delete(postId);
      } else {
        this.likedPostIds.add(postId);
      }
      if (isLiked) {
        await supabase.from('likes').delete().eq('post_id', postId).eq('user_id', auth.userId);
      } else {
        await supabase.from('likes').insert({ post_id: postId, user_id: auth.userId });
      }
      this.posts = this.sortPosts(this.posts);
    },
    async addComment(postId: string, text: string) {
      const auth = useAuthStore();
      const post = this.posts.find((item) => item.id === postId);
      if (!auth.userId || !post) return;
      post.commentCount = (post.commentCount ?? 0) + 1;
      post.recentCommentCount = (post.recentCommentCount ?? 0) + 1;
      post.popularityScore = this.calculatePopularityScore(post);
      await supabase.from('comments').insert({
        post_id: postId,
        user_id: auth.userId,
        text,
      });
      this.posts = this.sortPosts(this.posts);
    },
  },
});
