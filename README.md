# SoundScroll

SoundScroll is a Spotify-only, audio-first doom scroll feed for sharing short music moments.

## Stack
- Vue 3 + Vite + TypeScript + Pinia + Vue Router
- Supabase (Postgres + Auth)
- Spotify OAuth (Authorization Code with PKCE) + Web Playback SDK

## Setup

### 1) Spotify app
1. Create a Spotify app in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Add a Redirect URI that matches your local dev URL (example: `http://localhost:5173/feed`).
3. Copy the Client ID.

### 2) Supabase project
1. Create a new Supabase project.
2. In the SQL editor, run the migration in `supabase/migrations/001_init.sql`.
3. Make sure Row Level Security (RLS) is enabled (the migration does this).
4. Grab your `Project URL` and `anon` public key.

### 3) Environment variables
Copy `.env.example` to `.env` and fill in values:

```bash
cp .env.example .env
```

```
VITE_SUPABASE_URL=your-supabase-url
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_SPOTIFY_CLIENT_ID=your-spotify-client-id
VITE_SPOTIFY_REDIRECT_URI=http://localhost:5173/feed
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
- Spotify OAuth runs client-side with PKCE and stores tokens in session/local storage.
- Supabase Auth signs in anonymously to get a stable user ID for posting.
- Web Playback SDK is used for Premium accounts. Non-Premium accounts fall back to 30s previews (banner shows Preview mode).
- Autoplay begins after the first user gesture (“Enable Audio”).

## Feed ranking
The feed is generated client-side with constants in `src/stores/feed.ts`:
- `FEED_BASE = 1`
- `REPOST_BOOST = 1.5`
- `NEIGHBOR_BOOST = 1.2`
- `LIKE_BOOST = 0.25`
- Freshness decay: `1 / (1 + hours / 24)`

Taste neighbors are users who have liked or reposted at least 3 of the same `track_id`s as the current user in the last 30 days.
