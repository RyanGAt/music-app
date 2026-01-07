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
- `/profile` — create your profile (required before liking/commenting)
- `/u/:id` — profile page

## Behavior notes
- Supabase Auth signs in anonymously to get a stable user ID for posting.
- On first run you’ll be asked to create a profile (display name + optional avatar).
- Audio autoplay begins after the first user gesture (“Enable Audio”).
- Tracks are discovered via the Audius public API and cached in `tracks_cache`.
- The feed is auto-generated from random tracks; likes/comments are used to surface popularity.

## Feed ranking
The feed can be sorted by latest or popular. Popularity is based on likes/comments in the last 24 hours, with total counts as a fallback.

## Future add-ons (documentation only)
- Connect Spotify/SoundCloud later
  - save/like to the user’s chosen music app
  - add tracks to playlists
- Personalization
  - recommendations based on connected account likes/history
