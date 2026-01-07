import { defineStore } from 'pinia';
import { supabase } from '../lib/supabase';
import type { Track } from '../lib/musicProvider';
import { audiusProvider } from '../lib/audiusProvider';
import { useAuthStore } from './auth';

export type Post = {
  id: string;
  user_id: string;
  type: 'auto_moment' | 'song_moment' | 'repost';
  source: string;
  track_id: string | null;
  start_ms: number | null;
  text: string | null;
  original_post_id: string | null;
  created_at: string;
  profiles?: { id: string; display_name: string; avatar_url: string | null } | null;
  original?: Post | null;
  likeCount?: number;
  commentCount?: number;
};

const FEED_BASE = 1;
const REPOST_BOOST = 1.5;
const NEIGHBOR_BOOST = 1.2;
const LIKE_BOOST = 0.25;
const MIN_FEED_ITEMS = 30;
const MOMENT_WINDOW_MS = 15000;

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
    tasteNeighbors: new Set<string>(),
    likedPostIds: new Set<string>(),
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
    async computeTasteNeighbors(userId: string) {
      const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
      const { data: liked } = await supabase
        .from('likes')
        .select('user_id, post:posts!inner(track_id)')
        .gte('created_at', cutoff)
        .eq('user_id', userId);

      const { data: reposted } = await supabase
        .from('posts')
        .select('user_id, original:posts!original_post_id(track_id)')
        .eq('type', 'repost')
        .gte('created_at', cutoff)
        .eq('user_id', userId);

      const trackIds = new Set<string>();
      liked?.forEach((row) => {
        if (row.post?.track_id) trackIds.add(row.post.track_id);
      });
      reposted?.forEach((row) => {
        if (row.original?.track_id) trackIds.add(row.original.track_id);
      });

      if (trackIds.size === 0) {
        this.tasteNeighbors = new Set();
        return;
      }

      const { data: neighborLikes } = await supabase
        .from('likes')
        .select('user_id, post:posts!inner(track_id)')
        .gte('created_at', cutoff)
        .in('post.track_id', [...trackIds]);

      const { data: neighborReposts } = await supabase
        .from('posts')
        .select('user_id, original:posts!original_post_id(track_id)')
        .eq('type', 'repost')
        .gte('created_at', cutoff)
        .in('original.track_id', [...trackIds]);

      const counts = new Map<string, Set<string>>();
      const add = (neighborId: string, trackId: string) => {
        if (neighborId === userId) return;
        if (!counts.has(neighborId)) counts.set(neighborId, new Set());
        counts.get(neighborId)!.add(trackId);
      };

      neighborLikes?.forEach((row) => {
        if (row.post?.track_id && row.user_id) {
          if (row.user_id !== userId) add(row.user_id, row.post.track_id);
        }
      });

      neighborReposts?.forEach((row) => {
        if (row.original?.track_id && row.user_id) {
          if (row.user_id !== userId) add(row.user_id, row.original.track_id);
        }
      });

      const neighbors = new Set<string>();
      counts.forEach((trackSet, neighborId) => {
        if (trackSet.size >= 3) neighbors.add(neighborId);
      });
      this.tasteNeighbors = neighbors;
    },
    async loadPosts() {
      const { data: posts, error } = await supabase
        .from('posts')
        .select(
          'id, user_id, type, source, track_id, start_ms, text, original_post_id, created_at, profiles:profiles!posts_user_id_fkey(id, display_name, avatar_url), original:posts!original_post_id(id, user_id, type, source, track_id, start_ms, text, created_at, profiles:profiles!posts_user_id_fkey(id, display_name, avatar_url))',
        )
        .eq('visibility', 'public')
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

      const now = new Date().toISOString();
      const inserts = tracks.map((track) => {
        const maxStart = Math.max(0, track.duration_ms - MOMENT_WINDOW_MS);
        const startMs = maxStart > 0 ? Math.floor(Math.random() * maxStart) : 0;
        return {
          user_id: auth.userId,
          type: 'auto_moment',
          source: 'audius',
          track_id: track.id,
          start_ms: startMs,
          text: null,
          created_at: now,
        };
      });

      await supabase.from('posts').insert(inserts);
      await this.upsertTrackCache(tracks);
    },
    async fetchFeed() {
      const auth = useAuthStore();
      this.loading = true;
      await this.computeTasteNeighbors(auth.userId);

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
      const { data: likes } = await supabase.from('likes').select('post_id, user_id').in('post_id', postIds);
      const { data: comments } = await supabase.from('comments').select('post_id').in('post_id', postIds);
      const { data: userLikes } = await supabase
        .from('likes')
        .select('post_id')
        .eq('user_id', auth.userId)
        .in('post_id', postIds);

      this.likedPostIds = new Set(userLikes?.map((row) => row.post_id) ?? []);

      const likeCounts = new Map<string, number>();
      likes?.forEach((like) => {
        likeCounts.set(like.post_id, (likeCounts.get(like.post_id) ?? 0) + 1);
      });

      const commentCounts = new Map<string, number>();
      comments?.forEach((comment) => {
        commentCounts.set(comment.post_id, (commentCounts.get(comment.post_id) ?? 0) + 1);
      });

      const neighborLikes = new Set<string>();
      likes
        ?.filter((like) => this.tasteNeighbors.has(like.user_id))
        .forEach((like) => neighborLikes.add(like.post_id));

      const ranked = posts.map((post) => {
        const createdAt = new Date(post.created_at).getTime();
        const hours = (Date.now() - createdAt) / 36e5;
        const freshness = 1 / (1 + hours / 24);
        const isRepost = post.type === 'repost';
        const score =
          (FEED_BASE +
            (isRepost ? REPOST_BOOST : 0) +
            (likeCounts.get(post.id) ?? 0) * LIKE_BOOST +
            (this.tasteNeighbors.has(post.user_id) || neighborLikes.has(post.id) ? NEIGHBOR_BOOST : 0)) *
          freshness;
        return {
          ...post,
          likeCount: likeCounts.get(post.id) ?? 0,
          commentCount: commentCounts.get(post.id) ?? 0,
          score,
        } as Post & { score: number };
      });

      this.posts = ranked.sort((a, b) => b.score - a.score || Date.parse(b.created_at) - Date.parse(a.created_at));
      this.loading = false;
    },
    async toggleLike(postId: string, isLiked: boolean) {
      const auth = useAuthStore();
      if (isLiked) {
        await supabase.from('likes').delete().eq('post_id', postId).eq('user_id', auth.userId);
      } else {
        await supabase.from('likes').insert({ post_id: postId, user_id: auth.userId });
      }
      await this.fetchFeed();
    },
    async repost(postId: string, text: string | null) {
      const auth = useAuthStore();
      await supabase.from('posts').insert({
        type: 'repost',
        user_id: auth.userId,
        original_post_id: postId,
        text,
        source: 'audius',
      });
      await this.fetchFeed();
    },
    async addComment(postId: string, text: string) {
      const auth = useAuthStore();
      await supabase.from('comments').insert({
        post_id: postId,
        user_id: auth.userId,
        text,
      });
      await this.fetchFeed();
    },
  },
});
