create extension if not exists "pgcrypto";

create table if not exists profiles (
  id uuid primary key,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles (id) on delete cascade,
  type text not null,
  source text not null default 'audius',
  track_id text,
  start_ms int,
  text text,
  original_post_id uuid references posts (id) on delete set null,
  visibility text default 'public',
  created_at timestamptz default now()
);

create table if not exists tracks_cache (
  id text primary key,
  source text not null default 'audius',
  title text not null,
  artist text not null,
  duration_ms int not null,
  artwork_url text,
  permalink_url text,
  stream_url text,
  last_fetched_at timestamptz not null default now()
);

create table if not exists likes (
  user_id uuid references profiles (id) on delete cascade,
  post_id uuid references posts (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, post_id)
);

create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts (id) on delete cascade,
  user_id uuid references profiles (id) on delete cascade,
  text text,
  created_at timestamptz default now()
);

alter table posts drop constraint if exists posts_text_length;
alter table comments drop constraint if exists comments_text_length;
alter table posts drop constraint if exists posts_type_check;

alter table posts add constraint posts_text_length check (char_length(text) <= 120);
alter table comments add constraint comments_text_length check (char_length(text) <= 120);
alter table posts add constraint posts_type_check check (type in ('auto_moment', 'song_moment', 'repost'));

create index if not exists idx_posts_visibility_created_at on posts (visibility, created_at desc);
create index if not exists idx_posts_track_id on posts (track_id);
create index if not exists idx_posts_original_post_id on posts (original_post_id);
create index if not exists idx_posts_created_at on posts (created_at desc);
create index if not exists idx_likes_post_id on likes (post_id);
create index if not exists idx_likes_created_at on likes (created_at);
create index if not exists idx_comments_post_id on comments (post_id);

alter table profiles enable row level security;
alter table posts enable row level security;
alter table tracks_cache enable row level security;
alter table likes enable row level security;
alter table comments enable row level security;

create policy "Public profiles" on profiles for select using (true);
create policy "Users insert own profile" on profiles for insert with check (auth.uid() = id);
create policy "Users update own profile" on profiles for update using (auth.uid() = id);

create policy "Public posts" on posts for select using (visibility = 'public');
create policy "Users insert own posts" on posts for insert with check (auth.uid() = user_id);
create policy "Users update own posts" on posts for update using (auth.uid() = user_id);

create policy "Public tracks cache" on tracks_cache for select using (true);
create policy "Users insert tracks cache" on tracks_cache for insert with check (true);
create policy "Users update tracks cache" on tracks_cache for update using (true);

create policy "Users manage likes" on likes for insert with check (auth.uid() = user_id);
create policy "Users delete likes" on likes for delete using (auth.uid() = user_id);
create policy "Users read likes" on likes for select using (true);

create policy "Users read comments" on comments for select using (true);
create policy "Users insert comments" on comments for insert with check (auth.uid() = user_id);
