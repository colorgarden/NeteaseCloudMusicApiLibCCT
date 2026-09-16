#!/data/data/com.termux/files/usr/bin/sh
# tools/audio_to_dfpwm.sh
# Convert any audio file or direct URL into CC:Tweaked DFPWM (48 kHz, mono).
#
# Requires: ffmpeg and node.
#   Termux : pkg install ffmpeg nodejs-lts
#
# Usage:
#   tools/audio_to_dfpwm.sh <input-file-or-url> <output.dfpwm>
#
# Then host the .dfpwm and play it on the computer:
#   local audio = require("ncm.util.audio")
#   audio.playUrl("http://your-host/output.dfpwm", { volume = 1.0 })
set -e

IN="$1"
OUT="$2"
if [ -z "$IN" ] || [ -z "$OUT" ]; then
  echo "usage: $0 <input-file-or-url> <output.dfpwm>" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"

# Decode -> mono 48 kHz -> signed 8-bit PCM -> DFPWM.
ffmpeg -v error -i "$IN" -f s8 -ac 1 -ar 48000 - | node "$DIR/dfpwm_encode.js" > "$OUT"

echo "wrote $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
