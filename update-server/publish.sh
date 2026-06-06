#!/usr/bin/env bash
#
# publish.sh — push a TagStore release to the MinIO update bucket.
#
# The "update server" is just a public MinIO bucket: this script uploads the
# platform package(s) plus a generated latest.json manifest. The running app
# polls latest.json and self-updates. No web page, no domain, no server code.
#
# Prerequisites:
#   - MinIO client `mc` installed (https://min.io/docs/minio/linux/reference/minio-mc.html)
#   - An alias + a public-download bucket set up once (see ./README.md)
#
# Usage:
#   ./publish.sh <version> [--win <setup.exe>] [--mac <pkg.dmg>] [--linux <pkg.tar.gz>] \
#                [--notes "release notes"]
#
# Examples:
#   ./publish.sh 1.0.0.5 --win ../installer/TagStoreSetup_1.0.0.5.exe \
#                --notes "Improved AI tagging relevance."
#
# Config (override via env):
#   MC_ALIAS   mc alias name           (default: d2s)
#   BUCKET     bucket name             (default: tagstore-updates)
#   BASE_URL   public base URL, no /   (default: https://oss.d2ssoft.com/tagstore-updates)

set -euo pipefail

# Load MinIO credentials/config from the gitignored secret file next to this
# script (KEY=value lines; same format publish.ps1 reads).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${MINIO_CRED_FILE:-$SCRIPT_DIR/minio.secret.env}"
if [[ -f "$CRED_FILE" ]]; then
  set -a; # shellcheck disable=SC1090
  source "$CRED_FILE"; set +a
fi

MC_ALIAS="${MC_ALIAS:-${MINIO_ALIAS:-d2s}}"
BUCKET="${BUCKET:-${MINIO_BUCKET:-tagstore-updates}}"
BASE_URL="${BASE_URL:-${MINIO_BASE_URL:-https://oss.d2ssoft.com/tagstore-updates}}"

if ! command -v mc >/dev/null 2>&1; then
  echo "error: MinIO client 'mc' not found on PATH." >&2
  exit 1
fi

# Configure the mc alias from the secret file if endpoint + keys are present.
if [[ -n "${MINIO_ENDPOINT:-}" && -n "${MINIO_ACCESS_KEY:-}" && -n "${MINIO_SECRET_KEY:-}" ]]; then
  echo ">> configuring mc alias '$MC_ALIAS' -> $MINIO_ENDPOINT (from $(basename "$CRED_FILE"))"
  mc alias set "$MC_ALIAS" "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null
elif [[ ! -f "$CRED_FILE" ]]; then
  echo "error: credentials file not found: $CRED_FILE" >&2
  echo "       copy minio.secret.env.example to minio.secret.env and fill in your keys." >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <version> [--win f] [--mac f] [--linux f] [--notes \"...\"]" >&2
  exit 1
fi

VERSION="$1"; shift
WIN=""; MAC=""; LINUX=""; NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --win)   WIN="$2";   shift 2 ;;
    --mac)   MAC="$2";   shift 2 ;;
    --linux) LINUX="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Portable SHA-256 (Linux: sha256sum, macOS: shasum -a 256).
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# json-escape a string (handles quotes/backslashes/newlines for the notes field).
json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Build the platforms{} block, uploading each package as we go.
PLATFORMS=""
add_platform() {
  local key="$1" file="$2"
  [[ -z "$file" ]] && return 0
  if [[ ! -f "$file" ]]; then
    echo "error: $key package not found: $file" >&2
    exit 1
  fi
  local name; name="$(basename "$file")"
  local remote="${BUCKET}/${VERSION}/${name}"
  echo ">> uploading $key: $file -> ${MC_ALIAS}/${remote}"
  mc cp "$file" "${MC_ALIAS}/${remote}"
  local hash; hash="$(sha256 "$file")"
  local url="${BASE_URL}/${VERSION}/${name}"
  [[ -n "$PLATFORMS" ]] && PLATFORMS+=","
  PLATFORMS+="
    \"${key}\": { \"url\": \"${url}\", \"sha256\": \"${hash}\" }"
}

add_platform windows "$WIN"
add_platform macos   "$MAC"
add_platform linux   "$LINUX"

if [[ -z "$PLATFORMS" ]]; then
  echo "error: no packages given. Pass at least one of --win/--mac/--linux." >&2
  exit 1
fi

PUBDATE="$(date +%Y-%m-%d)"
NOTES_JSON="$(json_escape "$NOTES")"

cat > "$WORK/latest.json" <<EOF
{
  "version": "${VERSION}",
  "pubDate": "${PUBDATE}",
  "notes": ${NOTES_JSON},
  "platforms": {${PLATFORMS}
  }
}
EOF

echo ">> generated manifest:"
cat "$WORK/latest.json"

echo ">> uploading manifest (cache-control: no-cache)"
mc cp --attr "Cache-Control=no-cache" "$WORK/latest.json" "${MC_ALIAS}/${BUCKET}/latest.json"

echo ">> done. Clients will see ${VERSION} at ${BASE_URL}/latest.json"
