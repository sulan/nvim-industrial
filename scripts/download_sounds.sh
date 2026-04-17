#!/usr/bin/env bash
# scripts/download_sounds.sh
#
# Downloads and prepares CC0/public-domain industrial sound effects for nvim-industrial.
# Run from anywhere:  bash /path/to/nvim-industrial/scripts/download_sounds.sh
#
# Sources:
#   - OpenGameArt "68 Workshop Sounds" by Celianfrog (CC0 Public Domain)
#     https://opengameart.org/content/68-workshop-sounds
#   - ffmpeg audio synthesis for steam, explosion, and factory shutdown sounds
#
# Requirements: curl, ffmpeg (with libmp3lame)
# Optional:     7za / 7z (p7zip) — used to extract the workshop pack
#               On macOS: brew install p7zip
#               On Linux: apt install p7zip-full / pacman -S p7zip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUNDS_DIR="$(dirname "$SCRIPT_DIR")/sounds"
WORK_DIR="/tmp/nvim_industrial_sounds"

mkdir -p "$SOUNDS_DIR" "$WORK_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}[ok]${NC}    $*"; }
skip() { echo -e "  ${YELLOW}[skip]${NC}  $*"; }
warn() { echo -e "  ${RED}[warn]${NC}  $*" >&2; }
info() { echo -e "  ${CYAN}[info]${NC}  $*"; }
die()  { echo -e "  ${RED}[error]${NC} $*" >&2; exit 1; }

# ── Dependency checks ─────────────────────────────────────────────────────────

if ! command -v curl &>/dev/null; then
  die "curl is required. Install it and try again."
fi

if ! command -v ffmpeg &>/dev/null; then
  die "ffmpeg is required. Install it:\n  macOS: brew install ffmpeg\n  Linux: apt install ffmpeg"
fi

HAS_7Z=0
for candidate in 7za 7z; do
  if command -v "$candidate" &>/dev/null; then
    SEVENZ="$candidate"
    HAS_7Z=1
    break
  fi
done

if [ $HAS_7Z -eq 0 ]; then
  warn "7za/7z not found. Install p7zip to extract the workshop pack."
  warn "  macOS: brew install p7zip"
  warn "  Linux: sudo apt install p7zip-full  OR  sudo pacman -S p7zip"
  echo ""
  echo "Falling back to ffmpeg-synthesized sounds only."
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

sound_exists() {
  local name="$1"
  for ext in ogg wav mp3; do
    [ -f "$SOUNDS_DIR/${name}.${ext}" ] && return 0
  done
  return 1
}

conv_mp3() {
  # Convert $1 to MP3 at $2 (optionally trimmed)
  local src="$1" dest="$2" start="${3:-0}" dur="${4:-}"
  local args=()
  [ "$start" != "0" ] && args+=(-ss "$start")
  [ -n "$dur" ] && args+=(-t "$dur")
  ffmpeg "${args[@]}" -i "$src" -codec:a libmp3lame -qscale:a 3 -ar 44100 "$dest" -y -loglevel quiet
}

synth_mp3() {
  # Generate a sound from a lavfi filter graph
  local filtergraph="$1" dest="$2" duration="$3"
  ffmpeg -f lavfi -i "${filtergraph}:duration=${duration}" \
    -codec:a libmp3lame -qscale:a 3 -ar 44100 "$dest" -y -loglevel quiet
}

echo ""
echo "nvim-industrial sound downloader"
echo "================================="
echo "Output: $SOUNDS_DIR"
echo ""

# ── Step 1: Download and extract OpenGameArt workshop pack ────────────────────

WORKSHOP_PACK="$WORK_DIR/workshop.7z"
WORKSHOP_DIR="$WORK_DIR/workshop_sounds"

if [ $HAS_7Z -eq 1 ]; then
  info "Downloading OpenGameArt 68 Workshop Sounds (CC0, ~23MB)..."
  if [ -f "$WORKSHOP_PACK" ]; then
    skip "workshop.7z already cached"
  else
    if curl -fsSL --retry 3 --max-time 120 \
        -o "$WORKSHOP_PACK" \
        "https://opengameart.org/sites/default/files/workshop.7z"; then
      ok "workshop.7z downloaded"
    else
      warn "Failed to download workshop pack; using synthesized sounds for all"
      HAS_7Z=0
    fi
  fi

  if [ $HAS_7Z -eq 1 ]; then
    mkdir -p "$WORKSHOP_DIR"
    "$SEVENZ" e "$WORKSHOP_PACK" -o"$WORKSHOP_DIR/" -y >/dev/null 2>&1
    ok "Extracted workshop sounds"
  fi
fi

WS="$WORKSHOP_DIR"

# ── Step 2: Workshop pack sounds ──────────────────────────────────────────────

echo ""
echo "Processing sounds from workshop pack..."

if [ $HAS_7Z -eq 1 ]; then

  # hammer: short metallic clink (0.78s) → typing in insert mode
  if ! sound_exists "hammer"; then
    conv_mp3 "$WS/workshop - clink1.wav" "$SOUNDS_DIR/hammer.mp3"
    ok "hammer.mp3"
  else skip "hammer already exists"; fi

  # drill_start: power drill rev (trimmed 1.5s) → entering insert mode
  if ! sound_exists "drill_start"; then
    conv_mp3 "$WS/workshop - drill short 1.wav" "$SOUNDS_DIR/drill_start.mp3" 0 1.5
    ok "drill_start.mp3"
  else skip "drill_start already exists"; fi

  # rivet: pneumatic clink-thud (0.98s) → opening a file
  if ! sound_exists "rivet"; then
    conv_mp3 "$WS/workshop - clink thud.wav" "$SOUNDS_DIR/rivet.mp3"
    ok "rivet.mp3"
  else skip "rivet already exists"; fi

  # factory_bell: metallic jingle (1.96s) → Neovim startup
  if ! sound_exists "factory_bell"; then
    conv_mp3 "$WS/workshop - jingle.wav" "$SOUNDS_DIR/factory_bell.mp3"
    ok "factory_bell.mp3"
  else skip "factory_bell already exists"; fi

  # chainsaw: violent metal clatter (1.6s) → closing a buffer
  if ! sound_exists "chainsaw"; then
    conv_mp3 "$WS/workshop - loud clatter.wav" "$SOUNDS_DIR/chainsaw.mp3"
    ok "chainsaw.mp3"
  else skip "chainsaw already exists"; fi

  # grinder: metal scrape trimmed to 1.5s → text change in normal mode
  if ! sound_exists "grinder"; then
    conv_mp3 "$WS/workshop - scrape3.wav" "$SOUNDS_DIR/grinder.mp3" 0 1.5
    ok "grinder.mp3"
  else skip "grinder already exists"; fi

  # gear_crank: ratchet first click (0.6s) → entering command mode
  if ! sound_exists "gear_crank"; then
    conv_mp3 "$WS/workshop - ratchet1.wav" "$SOUNDS_DIR/gear_crank.mp3" 0 0.6
    ok "gear_crank.mp3"
  else skip "gear_crank already exists"; fi

else
  warn "Skipping workshop pack sounds (7z not available)"
fi

# ── Step 3: Synthesized sounds (ffmpeg only, no external assets) ──────────────

echo ""
echo "Synthesizing remaining sounds with ffmpeg..."

# steam_hiss: white noise burst with fast attack, short fade-out (0.5s)
# Simulates a quick pneumatic steam release when leaving insert mode
if ! sound_exists "steam_hiss"; then
  ffmpeg -f lavfi \
    -i "anoisesrc=color=white:duration=0.5" \
    -af "highpass=f=800,lowpass=f=6000,afade=t=in:d=0.02,afade=t=out:d=0.25:start_time=0.25,volume=1.5" \
    -codec:a libmp3lame -qscale:a 3 -ar 44100 \
    "$SOUNDS_DIR/steam_hiss.mp3" -y -loglevel quiet
  ok "steam_hiss.mp3 (synthesized)"
else skip "steam_hiss already exists"; fi

# explosion: brown noise burst with bass boost and limiter (0.8s)
# Brown noise has naturally more low-end than pink. Bass boost at 8dB (was 15)
# and volume=1.2 (was 4) prevent clipping. alimiter is an extra safeguard.
if ! sound_exists "explosion"; then
  ffmpeg -f lavfi \
    -i "anoisesrc=color=brown:duration=0.8" \
    -af "bass=gain=8:frequency=100:width_type=o:width=2,afade=t=in:d=0.005,afade=t=out:d=0.5:start_time=0.25,volume=1.2,alimiter=limit=0.9:attack=1:release=20" \
    -codec:a libmp3lame -qscale:a 3 -ar 44100 \
    "$SOUNDS_DIR/explosion.mp3" -y -loglevel quiet
  ok "explosion.mp3 (synthesized)"
else skip "explosion already exists"; fi

# factory_shutdown: exponentially decaying frequency chirp (1.5s)
# Sounds like a turbine or motor spinning down: frequency sweeps from ~280Hz
# to near-silence using phase = f0/k*(1-exp(-k*t)), k=2.5. A 6Hz amplitude
# wobble adds mechanical roughness. Sub-harmonic at 140Hz adds body.
if ! sound_exists "factory_shutdown"; then
  ffmpeg -f lavfi \
    -i "aevalsrc=sin(2*PI*112*(1-exp(-2.5*t)))*(1+0.25*sin(2*PI*6*t))*exp(-1.4*t)*0.6+sin(2*PI*56*(1-exp(-2.5*t)))*exp(-1.1*t)*0.35:sample_rate=44100:duration=1.5" \
    -af "afade=t=out:d=0.35:start_time=1.15,volume=2.5" \
    -codec:a libmp3lame -qscale:a 3 -ar 44100 \
    "$SOUNDS_DIR/factory_shutdown.mp3" -y -loglevel quiet
  ok "factory_shutdown.mp3 (synthesized)"
else skip "factory_shutdown already exists"; fi

# ── Fallback: if workshop pack unavailable, synthesize remaining sounds ────────

if [ $HAS_7Z -eq 0 ]; then
  echo ""
  echo "Synthesizing workshop-pack sounds (7z unavailable)..."

  # hammer: short metallic ping
  if ! sound_exists "hammer"; then
    ffmpeg -f lavfi \
      -i "aevalsrc=sin(2*PI*900*t)*exp(-t*25)+sin(2*PI*1800*t)*exp(-t*40)*0.4:sample_rate=44100:duration=0.5" \
      -codec:a libmp3lame -qscale:a 3 "$SOUNDS_DIR/hammer.mp3" -y -loglevel quiet
    ok "hammer.mp3 (synthesized fallback)"
  fi

  # drill_start: tremolo noise for drilling sound
  if ! sound_exists "drill_start"; then
    ffmpeg -f lavfi -i "anoisesrc=color=brown:duration=1.5" \
      -af "tremolo=f=40:d=0.8,highpass=f=300,afade=t=in:d=0.1,volume=2" \
      -codec:a libmp3lame -qscale:a 3 "$SOUNDS_DIR/drill_start.mp3" -y -loglevel quiet
    ok "drill_start.mp3 (synthesized fallback)"
  fi

  # rivet: very short noise pop
  if ! sound_exists "rivet"; then
    ffmpeg -f lavfi -i "anoisesrc=color=white:duration=0.15" \
      -af "highpass=f=500,afade=t=out:d=0.08,volume=3" \
      -codec:a libmp3lame -qscale:a 3 "$SOUNDS_DIR/rivet.mp3" -y -loglevel quiet
    ok "rivet.mp3 (synthesized fallback)"
  fi

  # factory_bell: metallic sine ring
  if ! sound_exists "factory_bell"; then
    ffmpeg -f lavfi \
      -i "aevalsrc=sin(2*PI*523*t)*exp(-t*2.5)+sin(2*PI*1046*t)*exp(-t*4)*0.3:sample_rate=44100:duration=2.0" \
      -codec:a libmp3lame -qscale:a 3 "$SOUNDS_DIR/factory_bell.mp3" -y -loglevel quiet
    ok "factory_bell.mp3 (synthesized fallback)"
  fi

  # chainsaw: tremolo on brown noise
  if ! sound_exists "chainsaw"; then
    ffmpeg -f lavfi -i "anoisesrc=color=brown:duration=1.5" \
      -af "tremolo=f=50:d=0.9,highpass=f=200,afade=t=in:d=0.05,volume=2.5" \
      -codec:a libmp3lame -qscale:a 3 "$SOUNDS_DIR/chainsaw.mp3" -y -loglevel quiet
    ok "chainsaw.mp3 (synthesized fallback)"
  fi

  # grinder: high-freq modulated noise
  if ! sound_exists "grinder"; then
    ffmpeg -f lavfi -i "anoisesrc=color=white:duration=1.0" \
      -af "highpass=f=1500,tremolo=f=80:d=0.6,volume=2" \
      -codec:a libmp3lame -qscale:a 3 "$SOUNDS_DIR/grinder.mp3" -y -loglevel quiet
    ok "grinder.mp3 (synthesized fallback)"
  fi

  # gear_crank: rapid clicks via sine bursts
  if ! sound_exists "gear_crank"; then
    ffmpeg -f lavfi \
      -i "aevalsrc=if(gt(mod(t,0.1),0.08),sin(2*PI*400*t)*exp(-mod(t,0.1)*150),0):sample_rate=44100:duration=0.7" \
      -af "volume=4" \
      -codec:a libmp3lame -qscale:a 3 "$SOUNDS_DIR/gear_crank.mp3" -y -loglevel quiet
    ok "gear_crank.mp3 (synthesized fallback)"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

REQUIRED=(hammer drill_start steam_hiss explosion rivet chainsaw factory_bell factory_shutdown grinder gear_crank)
MISSING=()
for name in "${REQUIRED[@]}"; do
  sound_exists "$name" || MISSING+=("$name")
done

echo ""
if [ ${#MISSING[@]} -eq 0 ]; then
  echo -e "${GREEN}All 10 sounds ready in $SOUNDS_DIR${NC}"
  echo ""
  ls -lh "$SOUNDS_DIR"
else
  echo -e "${YELLOW}Missing: ${MISSING[*]}${NC}"
  echo "Manually place any short audio file named <sound>.mp3 in: $SOUNDS_DIR"
fi

echo ""
echo "Test a sound:"
echo "  macOS: afplay $SOUNDS_DIR/explosion.mp3"
echo "  Linux: paplay $SOUNDS_DIR/explosion.mp3"
