#!/usr/bin/env bash
# Reel editor setup: video-use + HyperFrames + yt-dlp + FFmpeg/Python/Node
# Run from the folder you want to use as your editing workspace:
#   bash setup-reel-editor.sh
# macOS (Homebrew) and Debian/Ubuntu (apt) supported. On Windows, run inside WSL2.
set -euo pipefail

WORKDIR="$(pwd)"
OS="$(uname -s)"

say() { printf "\n\033[1m== %s\033[0m\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 1. System dependencies ----------
say "System dependencies (FFmpeg, Python, Node.js, git, yt-dlp)"
if [ "$OS" = "Darwin" ]; then
  if ! have brew; then
    echo "Homebrew missing. Install it first: https://brew.sh" && exit 1
  fi
  have ffmpeg  || brew install ffmpeg
  have python3 || brew install python
  have node    || brew install node
  have git     || brew install git
  have yt-dlp  || brew install yt-dlp
elif have apt-get; then
  sudo apt-get update
  have ffmpeg  || sudo apt-get install -y ffmpeg
  have python3 || sudo apt-get install -y python3 python3-pip python3-venv
  have node    || sudo apt-get install -y nodejs npm
  have git     || sudo apt-get install -y git
  have yt-dlp  || { python3 -m pip install --user -U yt-dlp || sudo apt-get install -y yt-dlp; }
else
  echo "Unsupported OS. Install ffmpeg, python3, node, git, yt-dlp manually, then re-run." && exit 1
fi

# uv (used by video-use for dependency sync)
have uv || python3 -m pip install --user -U uv || curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# ---------- 2. video-use ----------
say "video-use (browser-use/video-use)"
if [ ! -d "$WORKDIR/video-use" ]; then
  git clone https://github.com/browser-use/video-use "$WORKDIR/video-use"
fi
mkdir -p "$HOME/.claude/skills"
ln -sfn "$WORKDIR/video-use" "$HOME/.claude/skills/video-use"
( cd "$WORKDIR/video-use" && { uv sync || python3 -m pip install -e .; } )

# ElevenLabs key: taken from env var or prompted silently. Never hardcoded.
ENV_FILE="$WORKDIR/video-use/.env"
if [ ! -f "$ENV_FILE" ]; then
  KEY="${ELEVENLABS_API_KEY:-}"
  if [ -z "$KEY" ]; then
    read -r -s -p "Paste your ElevenLabs API key (input hidden): " KEY; echo
  fi
  printf "ELEVENLABS_API_KEY=%s\n" "$KEY" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi

# ---------- 3. HyperFrames ----------
say "HyperFrames (motion graphics)"
# Installs the HyperFrames agent skills; the CLI itself runs via npx.
npx --yes skills add heygen-com/hyperframes --full-depth --yes
npx --yes hyperframes doctor || echo "(doctor reported issues, see output above)"

# ---------- 4. Workspace defaults for vertical reels ----------
say "Workspace"
mkdir -p "$WORKDIR/raw" "$WORKDIR/reference"
if [ ! -f "$WORKDIR/CLAUDE.md" ]; then
cat > "$WORKDIR/CLAUDE.md" <<'EOF'
# Reel workspace
- Output format: vertical 9:16, 1080x1920, 30 fps, H.264 MP4 (AAC audio).
- Keep captions and key graphics inside the platform safe zones (avoid top/bottom UI overlap).
- Raw footage goes in ./raw. Reference reels downloaded with yt-dlp go in ./reference.
- Motion graphics: HyperFrames compositions must be 1080x1920.
- Always propose an edit strategy and wait for approval before cutting.
EOF
fi

# ---------- 5. Verify ----------
say "Versions"
ffmpeg -version | head -n1
python3 --version
node --version
yt-dlp --version
have claude && claude --version || echo "Claude Code not found: install it from https://claude.com/product/claude-code to drive video-use."

say "Done. Next: cd \"$WORKDIR\" && claude   (then: 'edit the clips in ./raw into a 9:16 reel')"
