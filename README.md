# SoundScroll

SoundScroll is an audio-first doom scroll feed for sharing short music moments discovered on Audius.

## Stack
- Vue 3 + Vite + TypeScript + Pinia + Vue Router
- Supabase (Postgres + Auth)
- HTMLAudioElement + Web Audio API fades

## Setup

### 1) Supabase project
1. Create a new Supabase project.
2. In the SQL editor, run the migration in `supabase/migrations/001_init.sql`.
3. Make sure Row Level Security (RLS) is enabled (the migration does this).
4. Grab your `Project URL` and `anon` public key.

### 2) Audius API
- No API key is required for basic read access.
- The app selects a healthy Audius discovery host dynamically from `https://api.audius.co`.

### 3) Environment variables
Create a `.env` file and fill in values:

```
VITE_SUPABASE_URL=your-supabase-url
VITE_SUPABASE_ANON_KEY=your-anon-key
```

### 4) Install + run

```bash
npm install
npm run dev
```

## Core routes
- `/feed` — main doom-scroll feed
- `/create` — create a song moment post
- `/u/:id` — profile page

## Behavior notes
- Supabase Auth signs in anonymously to get a stable user ID for posting.
- Audio autoplay begins after the first user gesture (“Enable Audio”).
- Tracks are discovered via the Audius public API and cached in `tracks_cache`.
- Likes, reposts, and comments live inside SoundScroll only.

## Feed ranking
The feed is generated client-side with constants in `src/stores/feed.ts`:
- `FEED_BASE = 1`
- `REPOST_BOOST = 1.5`
- `NEIGHBOR_BOOST = 1.2`
- `LIKE_BOOST = 0.25`
- Freshness decay: `1 / (1 + hours / 24)`

Taste neighbors are users who have liked or reposted at least 3 of the same `track_id`s as the current user in the last 30 days.

## Future add-ons (documentation only)
- Connect Spotify/SoundCloud later
  - save/like to the user’s chosen music app
  - add tracks to playlists
- Personalization
  - recommendations based on connected account likes/history
