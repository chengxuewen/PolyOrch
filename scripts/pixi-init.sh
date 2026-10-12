#!/usr/bin/env bash
# pixi-init.sh -- standard pixi bootstrap for PolyOrch-embedding hosts.
#
# Three stages, parameterized by --manifest-path:
#   [1/3] locate or install pixi (auditable installer: downloaded to a file and
#         executed -- never curl|sh; gitee mirror fallback via PIXI_REPOURL;
#         pinned version with a hard assert)
#   [2/3] pixi install --manifest-path <manifest> (on lock drift: regenerate
#         the lock once and retry -- the archived proven recovery pattern)
#   [3/3] smoke (version print; hosts add their own verify task if they have one)
#
# Scope note: this script does NOT configure cargo mirrors/registries -- that is
# host network policy, owned by the host's own bootstrap (e.g. VisiaEngine's
# bootstrap.sh adds its own cargo mirror stage on top of this one).
#
# Usage:
#   bash scripts/pixi-init.sh                                  # PolyOrch's own pixi.toml
#   bash scripts/pixi-init.sh --manifest-path /path/pixi.toml  # a host manifest
# Env knobs:
#   PIXI_VERSION  (default 0.78.0; keep in sync with the CI pin)
#   PIXI_REPOURL  (default upstream; point at a gitee fork for CN mirrors)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PIXI_VERSION="${PIXI_VERSION:-0.78.0}"
PIXI_BIN="$HOME/.pixi/bin/pixi"

pixi_version() { "$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1; }
ver_ge() { # ver_ge <have> <need>: true if have >= need
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# ---- resolve the manifest ----
MANIFEST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest-path)
      MANIFEST="$2"; shift 2 ;;
    *)
      echo "ERROR: unknown argument '$1' (usage: pixi-init.sh [--manifest-path <pixi.toml>])" >&2
      exit 1 ;;
  esac
done
if [ -z "$MANIFEST" ]; then
  MANIFEST="$(dirname "$SCRIPT_DIR")/pixi.toml"
fi
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: manifest not found: $MANIFEST" >&2
  exit 1
fi
MANIFEST="$(cd "$(dirname "$MANIFEST")" && pwd)/$(basename "$MANIFEST")"

echo "=== pixi-init: manifest = $MANIFEST (pin $PIXI_VERSION) ==="

# ---- [1/3] locate or install pixi ----
PIXI=""
if command -v pixi >/dev/null 2>&1; then
  PIXI="$(command -v pixi)"
elif [ -x "$PIXI_BIN" ]; then
  PIXI="$PIXI_BIN"
fi

if [ -n "$PIXI" ]; then
  have="$(pixi_version "$PIXI")"
  if ver_ge "${have:-0}" "$PIXI_VERSION"; then
    echo "[1/3] pixi ${have} ready (${PIXI})"
  else
    echo "[1/3] existing pixi ${have} is below the pinned ${PIXI_VERSION}; reinstalling into ~/.pixi ..."
    PIXI=""
  fi
fi

if [ -z "$PIXI" ]; then
  echo "[1/3] network preflight: conda-forge reachability..."
  if ! curl -sI --max-time 10 https://conda.anaconda.org/conda-forge/noarch/repodata.json >/dev/null 2>&1; then
    echo "ERROR: cannot reach conda-forge. Configure a mirror and retry." >&2
    exit 1
  fi
  tmp_inst="$(mktemp)"
  if ! curl -fsSL --proto '=https' --tlsv1.2 "https://pixi.sh/install.sh" -o "$tmp_inst"; then
    echo "ERROR: pixi installer download failed" >&2
    rm -f "$tmp_inst"
    exit 1
  fi
  # Execute from a downloaded file (auditable), never curl|sh; the version
  # assert below backstops whatever the installer actually delivered.
  PIXI_VERSION="v${PIXI_VERSION}" bash "$tmp_inst"
  rc=$?
  rm -f "$tmp_inst"
  [ "$rc" -eq 0 ] || { echo "ERROR: pixi installer execution failed (rc=$rc)" >&2; exit 1; }
  PIXI="$PIXI_BIN"
fi

got="$(pixi_version "$PIXI")"
if ! ver_ge "${got:-0}" "$PIXI_VERSION"; then
  echo "ERROR: pixi version assert failed: got '${got:-none}', need >= ${PIXI_VERSION}" >&2
  exit 1
fi

# ---- [2/3] resolve and install the environment ----
echo "[2/3] pixi install (first solve includes downloads; may take minutes)..."
if "$PIXI" install --manifest-path "$MANIFEST"; then
  :
else
  echo "      first solve failed -> regenerate the lock and retry once (lock-drift recovery)"
  "$PIXI" update --manifest-path "$MANIFEST" \
    || { echo "ERROR: pixi update failed" >&2; exit 1; }
  "$PIXI" install --manifest-path "$MANIFEST" \
    || { echo "ERROR: pixi install failed (after lock regeneration)" >&2; exit 1; }
fi

# ---- [3/3] smoke ----
echo "[3/3] smoke: pixi --version via ~/.pixi/bin ..."
"$PIXI" --version || { echo "ERROR: pixi smoke failed" >&2; exit 1; }

echo "=== pixi-init done ==="
echo "  activate:      source $SCRIPT_DIR/pixi.sh   (hosts: their own activation script)"
echo "  daily use:     $PIXI run <task> --manifest-path $MANIFEST"
