#!/usr/bin/env bash
#
# stream.sh
# Builds an FFmpeg concat playlist from videos.txt and pushes it to one or
# more RTMP destinations (YouTube, TikTok) simultaneously using the `tee`
# muxer. Runs for just under GitHub Actions' 6-hour hard limit, then exits
# cleanly so the workflow can hand off to the next run.

set -euo pipefail

cd "$(dirname "$0")/.."

VIDEO_LIST="videos.txt"
CONCAT_FILE="concat_list.txt"

if [ ! -s "$VIDEO_LIST" ]; then
  echo "videos.txt is empty or missing. Add one video URL/path per line." >&2
  exit 1
fi

# Build the concat demuxer playlist
: > "$CONCAT_FILE"
while IFS= read -r line; do
  # skip blank lines and comments
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  echo "file '$line'" >> "$CONCAT_FILE"
done < "$VIDEO_LIST"

if [ ! -s "$CONCAT_FILE" ]; then
  echo "No valid video entries found in videos.txt" >&2
  exit 1
fi

# Assemble the tee output string based on which secrets are present
TEE_OUTPUTS=""

if [ -n "${YOUTUBE_STREAM_KEY:-}" ]; then
  TEE_OUTPUTS="${TEE_OUTPUTS}[f=flv]rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_STREAM_KEY}|"
fi

if [ -n "${TIKTOK_STREAM_KEY:-}" ]; then
  # TikTok gives you a full ingest URL when you enable LIVE Studio access;
  # TIKTOK_INGEST_URL defaults to the common endpoint but check your
  # LIVE Studio dashboard, since TikTok sometimes issues a region-specific host.
  TIKTOK_INGEST_URL="${TIKTOK_INGEST_URL:-rtmp://push-rtmp-l1-va01.tiktokcdn.com/live}"
  TEE_OUTPUTS="${TEE_OUTPUTS}[f=flv]${TIKTOK_INGEST_URL}/${TIKTOK_STREAM_KEY}|"
fi

TEE_OUTPUTS="${TEE_OUTPUTS%|}"

if [ -z "$TEE_OUTPUTS" ]; then
  echo "No stream keys set (YOUTUBE_STREAM_KEY / TIKTOK_STREAM_KEY). Nothing to do." >&2
  exit 1
fi

echo "Streaming to: $TEE_OUTPUTS"

# Run just under 6 hours so the job self-terminates before GitHub kills it.
# -stream_loop -1 loops the whole playlist indefinitely within this run.
timeout 350m ffmpeg -hide_banner -loglevel warning \
  -protocol_whitelist file,http,https,tcp,tls,crypto \
  -re -f concat -safe 0 -stream_loop -1 -i "$CONCAT_FILE" \
  -c:v libx264 -preset veryfast -tune zerolatency \
  -b:v 4500k -maxrate 4500k -bufsize 9000k -pix_fmt yuv420p \
  -g 60 -r 30 \
  -c:a aac -b:a 128k -ar 44100 \
  -f tee "$TEE_OUTPUTS"

echo "Stream segment finished (timeout or playlist exhausted)."
