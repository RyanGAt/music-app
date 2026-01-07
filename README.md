# SoundScroll

SoundScroll is a local-first, audio-first doom scroll feed for sharing short music moments using a mock catalog.

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

### 2) Environment variables
Copy `.env.example` to `.env` and fill in values:

```bash
cp .env.example .env
```

```
VITE_SUPABASE_URL=your-supabase-url
VITE_SUPABASE_ANON_KEY=your-anon-key
```

### 3) Local audio previews
Add short mp3 previews into `/public/audio`. The repo ships with placeholder mp3 files you can replace. Update the mock catalog in `src/mock/catalog.json` to point at your local files, for example:

```
/public/audio/lofi-drift.mp3
/public/audio/night-drive.mp3
```

The catalog also supports remote mp3 URLs if you prefer.

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
- Track data comes from the mock catalog in `src/mock/catalog.json` (no Spotify or external APIs).

## Feed ranking
The feed is generated client-side with constants in `src/stores/feed.ts`:
- `FEED_BASE = 1`
- `REPOST_BOOST = 1.5`
- `NEIGHBOR_BOOST = 1.2`
- `LIKE_BOOST = 0.25`
- Freshness decay: `1 / (1 + hours / 24)`

Taste neighbors are users who have liked or reposted at least 3 of the same `track_id`s as the current user in the last 30 days.
