# Free 24/7 Restreamer (GitHub Actions + FFmpeg)

Restreams your videos to YouTube Live and/or TikTok Live continuously using
GitHub's free Actions runners. No server, no credit card.

## How it works

- `videos.txt` lists the videos to loop.
- `scripts/stream.sh` builds an FFmpeg concat playlist and pushes it via the
  `tee` muxer to YouTube and/or TikTok's RTMP ingest at the same time.
- Each run is capped at 5h50m (GitHub kills jobs at 6h). Right before
  exiting, the workflow calls the GitHub API to immediately kick off the
  next run, so the gap between sessions is a few seconds, not minutes.
- A cron trigger (every 6 hours) acts as a backup in case the self-trigger
  ever fails, so the stream can't permanently die from one hiccup.

## Setup

### 1. Create the repo
Push this folder to a new GitHub repository (public or private, both work
with Actions' free tier — public repos get more free minutes).

### 2. Add your videos
Edit `videos.txt` — one entry per line, either:
- A direct HTTPS link to an .mp4 (must resolve straight to the file, not a
  webpage), or
- A path to a video file you've committed into the repo (e.g. `media/a.mp4`)
  — fine for small clips, but GitHub repos have storage/size limits, so
  external links are usually better for anything large.

### 3. Get your YouTube stream key
YouTube Studio → **Go Live** → **Stream** tab → copy the **Stream key**.
Note: a brand-new YouTube channel may need to wait ~24h after first
enabling live streaming before it's able to go live.

### 4. Get your TikTok stream key (if eligible)
TikTok app → **Live** → **LIVE Studio** (or **LIVE Center** on web) → look
for the RTMP stream key / server URL. This option only appears once TikTok
has granted your account LIVE access — eligibility varies by
region/account and isn't something this script can unlock. If you don't
see it, the YouTube half of this setup still works on its own.

### 5. Add repo secrets
In your repo: **Settings → Secrets and variables → Actions → New repository
secret**. Add whichever of these apply:

| Secret | Required | Notes |
|---|---|---|
| `YOUTUBE_STREAM_KEY` | For YouTube | From step 3 |
| `TIKTOK_STREAM_KEY` | For TikTok | From step 4 |
| `TIKTOK_INGEST_URL` | Optional | Only if TikTok gives you a non-default ingest host; otherwise the script's default is used |
| `GH_PAT` | Recommended | A [personal access token](https://github.com/settings/tokens) with `repo` + `workflow` scope. Without it, sessions still restart, just on the slower 6-hour cron instead of instantly. |

### 6. Turn it on
Go to the **Actions** tab in your repo → select **Restream to
YouTube/TikTok** → **Run workflow**. After that, it keeps re-triggering
itself.

## Tuning

- Bitrate/resolution: edit the `-b:v`, `-maxrate`, `-bufsize` values in
  `scripts/stream.sh` (4500k is a safe default for 1080p30).
- To stream to only one platform, just add that platform's secret and
  leave the other blank — the script skips any destination without a key.

## Things to keep in mind

- **GitHub Actions free-tier minutes**: public repos get unlimited Actions
  minutes; private repos get a monthly quota (2,000 min/month on the free
  plan) — running 24/7 in a private repo will burn through that fast. Use
  a public repo for continuous streaming, or watch your usage.
- **Platform policies**: both YouTube and TikTok have rules around
  repetitive/looped or spam-like live content. Since you're rebroadcasting
  your own existing videos, it's worth a quick check of each platform's
  current live-streaming/reused-content guidelines for your situation.
- **Stream keys are secrets** — never commit them directly into
  `videos.txt` or any tracked file, only into repo Secrets.
