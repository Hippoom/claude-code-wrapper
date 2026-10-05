#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BIN_DIR=${1:-"$HOME/bin"}
if [ -n "${CCW_CONFIG_DIR:-}" ]; then
  CONFIG_DIR=$CCW_CONFIG_DIR
else
  CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ccw"
fi

if [ ! -f "$SCRIPT_DIR/ccw" ]; then
  printf 'ccw installer: launcher not found at %s/ccw\n' "$SCRIPT_DIR" >&2
  exit 1
fi

umask 077
mkdir -p "$BIN_DIR" "$CONFIG_DIR/providers" "$CONFIG_DIR/keys"
if [ -d "$BIN_DIR/ccw" ]; then
  printf 'ccw installer: destination is a directory: %s/ccw\n' "$BIN_DIR" >&2
  exit 1
fi
for alias in claude-wrapper claude-code-wrapper; do
  if [ -e "$BIN_DIR/$alias" ] && [ ! -L "$BIN_DIR/$alias" ]; then
    printf 'ccw installer: refusing to replace existing non-symlink: %s/%s\n' "$BIN_DIR" "$alias" >&2
    exit 1
  fi
done

TEMP_LAUNCHER="$BIN_DIR/.ccw.$$"
trap 'rm -f "$TEMP_LAUNCHER"' EXIT HUP INT TERM
install -m 755 "$SCRIPT_DIR/ccw" "$TEMP_LAUNCHER"
mv -f "$TEMP_LAUNCHER" "$BIN_DIR/ccw"
ln -sfn ccw "$BIN_DIR/claude-wrapper"
ln -sfn ccw "$BIN_DIR/claude-code-wrapper"
trap - EXIT HUP INT TERM

printf 'Installed CCW commands to %s:\n' "$BIN_DIR"
printf '  ccw\n  claude-wrapper -> ccw\n  claude-code-wrapper -> ccw\n'
printf 'Created configuration directories:\n  %s/providers\n  %s/keys\n' "$CONFIG_DIR" "$CONFIG_DIR"
case ":${PATH:-}:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Add this directory to PATH if needed: %s\n' "$BIN_DIR" ;;
esac
