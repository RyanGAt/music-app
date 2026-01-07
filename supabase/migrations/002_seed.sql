insert into profiles (id, display_name, avatar_url)
values
  (gen_random_uuid(), 'Nova Echo', null),
  (gen_random_uuid(), 'Midnight Relay', null),
  (gen_random_uuid(), 'Static Bloom', null)
returning id;

with seeded_profiles as (
  select id, row_number() over () as rn
  from profiles
  order by created_at desc
  limit 3
),
seeded_posts as (
  insert into posts (user_id, type, track_id, start_ms, text)
  select
    (select id from seeded_profiles where rn = 1),
    'song_moment',
    'lofi-drift',
    15000,
    'Rainy commute, volume up.'
  union all
  select
    (select id from seeded_profiles where rn = 2),
    'song_moment',
    'night-drive',
    42000,
    'City lights blur into neon.'
  union all
  select
    (select id from seeded_profiles where rn = 3),
    'song_moment',
    'golden-hour',
    8000,
    'Soft reset before the night.'
  returning id, user_id
)
insert into posts (user_id, type, original_post_id, text)
select
  (select id from seeded_profiles where rn = 1),
  'repost',
  (select id from seeded_posts limit 1),
  'Need this energy.';

with seeded_profiles as (
  select id, row_number() over () as rn
  from profiles
  order by created_at desc
  limit 3
),
seeded_posts as (
  select id, row_number() over () as rn
  from posts
  order by created_at desc
  limit 4
)
insert into likes (user_id, post_id)
select
  (select id from seeded_profiles where rn = 2),
  (select id from seeded_posts where rn = 1)
union all
select
  (select id from seeded_profiles where rn = 3),
  (select id from seeded_posts where rn = 2);

with seeded_profiles as (
  select id, row_number() over () as rn
  from profiles
  order by created_at desc
  limit 3
),
seeded_posts as (
  select id, row_number() over () as rn
  from posts
  order by created_at desc
  limit 4
)
insert into comments (post_id, user_id, text)
select
  (select id from seeded_posts where rn = 1),
  (select id from seeded_profiles where rn = 3),
  'Looping this.'
union all
select
  (select id from seeded_posts where rn = 2),
  (select id from seeded_profiles where rn = 1),
  'Perfect for late-night drives.';
