#!/bin/zsh
set -e

ROOT="${0:A:h:h}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
  local value="$1" expected="$2" message="$3"
  [[ "$value" == *"$expected"* ]] || fail "$message (missing '$expected')"
}

mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/xdg/ccw/providers" "$TEST_ROOT/xdg/ccw/keys" \
  "$TEST_ROOT/override/providers" "$TEST_ROOT/override/keys" "$TEST_ROOT/bin" \
  "$TEST_ROOT/legacy/keys" "$TEST_ROOT/project/subdir" "$TEST_ROOT/no-config-project" \
  "$TEST_ROOT/marker-project" "$TEST_ROOT/old-marker-project"
chmod 700 "$TEST_ROOT/xdg/ccw" "$TEST_ROOT/xdg/ccw/keys" "$TEST_ROOT/override" \
  "$TEST_ROOT/override/keys" "$TEST_ROOT/legacy" "$TEST_ROOT/legacy/keys"

cat > "$TEST_ROOT/xdg/ccw/providers/ds.sh" <<'EOF'
export ANTHROPIC_BASE_URL="https://ds.example.invalid"
export ANTHROPIC_MODEL="ds-model"
EOF
cat > "$TEST_ROOT/xdg/ccw/providers/gpt.sh" <<'EOF'
export ANTHROPIC_BASE_URL="https://gpt.example.invalid"
export ANTHROPIC_MODEL="gpt-model"
EOF
cat > "$TEST_ROOT/override/providers/gpt.sh" <<'EOF'
export ANTHROPIC_BASE_URL="https://override.example.invalid"
export ANTHROPIC_MODEL="override-model"
EOF
cat > "$TEST_ROOT/legacy/providers-ds.sh" <<'EOF'
export ANTHROPIC_BASE_URL="https://legacy.example.invalid"
export ANTHROPIC_MODEL="legacy-model"
EOF
mkdir -p "$TEST_ROOT/legacy/providers"
mv "$TEST_ROOT/legacy/providers-ds.sh" "$TEST_ROOT/legacy/providers/ds.sh"
for config in "$TEST_ROOT/xdg/ccw" "$TEST_ROOT/override" "$TEST_ROOT/legacy"; do
  : > "$config/keys/test-key.sh"
done
cat > "$TEST_ROOT/xdg/ccw/keys/test-key.sh" <<'EOF'
export ANTHROPIC_API_KEY="test-key-value"
EOF
cat > "$TEST_ROOT/override/keys/test-key.sh" <<'EOF'
export ANTHROPIC_API_KEY="test-key-value"
EOF
cat > "$TEST_ROOT/legacy/keys/test-key.sh" <<'EOF'
export ANTHROPIC_API_KEY="test-key-value"
EOF
chmod 600 "$TEST_ROOT/xdg/ccw/keys/test-key.sh" "$TEST_ROOT/override/keys/test-key.sh" "$TEST_ROOT/legacy/keys/test-key.sh"

cat > "$TEST_ROOT/bin/claude" <<'EOF'
#!/bin/zsh
print -r -- "$0" > "$CCW_TEST_CALLED"
print -r -- "${ANTHROPIC_BASE_URL:-}" > "$CCW_TEST_BASE_URL"
print -r -- "${ANTHROPIC_MODEL:-}" > "$CCW_TEST_MODEL"
print -r -- "${ANTHROPIC_API_KEY:-}" > "$CCW_TEST_API_KEY"
print -r -- "${CLAUDE_CODE_SIMPLE:-}" > "$CCW_TEST_SIMPLE"
printf '%s\n' "$@" > "$CCW_TEST_ARGS"
exit "${CCW_TEST_EXIT:-0}"
EOF
chmod +x "$TEST_ROOT/bin/claude"
cp "$TEST_ROOT/bin/claude" "$TEST_ROOT/bin/claude-custom"

print -r -- test-key > "$TEST_ROOT/project/.ccw"
print -r -- test-key > "$TEST_ROOT/old-marker-project/.claude-provider"
mkdir -p "$TEST_ROOT/home/.claude-profiles/keys"
cp "$TEST_ROOT/legacy/providers/ds.sh" "$TEST_ROOT/home/.claude-profiles/ds.sh"
cp "$TEST_ROOT/legacy/keys/test-key.sh" "$TEST_ROOT/home/.claude-profiles/keys/test-key.sh"

# XDG default and parent-directory marker discovery.
output="$(cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" \
  CCW_CONFIG_DIR= "$ROOT/ccw" --ds --which)"
assert_contains "$output" "$TEST_ROOT/xdg/ccw/providers/ds.sh" "XDG config path"
assert_contains "$output" "$TEST_ROOT/xdg/ccw/keys/test-key.sh" "parent .ccw discovery"

# Explicit config root overrides the XDG default.
output="$(cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" \
  CCW_CONFIG_DIR="$TEST_ROOT/override" "$ROOT/ccw" --gpt --which)"
assert_contains "$output" "$TEST_ROOT/override/providers/gpt.sh" "CCW_CONFIG_DIR precedence"
assert_contains "$(cat "$TEST_ROOT/override/providers/gpt.sh")" "override.example.invalid" "override fixture"

# Legacy config directory and old wrapper env var are not runtime fallbacks.
output="$(cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/empty-xdg" \
  CCW_CONFIG_DIR= CCLAUDE_CONFIG_DIR="$TEST_ROOT/legacy" "$ROOT/ccw" --which 2>&1)"
assert_contains "$output" "Provider: <not specified>" "old wrapper env var is ignored"
[[ "$output" != *"legacy/providers"* ]] || fail "CCW must not read CCLAUDE_CONFIG_DIR"

# Legacy project markers are ignored, even when the provider exists.
if output="$(cd "$TEST_ROOT/old-marker-project" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" \
  CCW_CONFIG_DIR= "$ROOT/ccw" --ds --which 2>&1)"; then
  fail "legacy .claude-provider marker must not be read"
else
  assert_contains "$output" "No key found" "legacy project marker is ignored"
fi

# Explicit provider selection writes a new .ccw marker.
output="$(cd "$TEST_ROOT/marker-project" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" \
  CCW_CONFIG_DIR= "$ROOT/ccw" --provider ds:test-key --which)"
assert_eq "$(cat "$TEST_ROOT/marker-project/.ccw")" "test-key" "explicit selection writes .ccw"
assert_contains "$output" "$TEST_ROOT/xdg/ccw/providers/ds.sh" "explicit provider selection"

# No legacy config path is used when the XDG config does not exist.
output="$(cd "$TEST_ROOT/no-config-project" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/empty-xdg" \
  CCW_CONFIG_DIR= "$ROOT/ccw" --ds --which 2>&1 || true)"
assert_contains "$output" "Must specify a provider" "legacy home config is ignored"

# Full mode clears inherited Claude Code simple mode and forwards args exactly.
(cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" CCW_CONFIG_DIR= \
  PATH="$TEST_ROOT/bin:$PATH" CCW_TEST_CALLED="$TEST_ROOT/called" CCW_TEST_BASE_URL="$TEST_ROOT/base" \
  CCW_TEST_MODEL="$TEST_ROOT/model" CCW_TEST_API_KEY="$TEST_ROOT/key" CCW_TEST_SIMPLE="$TEST_ROOT/simple" \
  CCW_TEST_ARGS="$TEST_ROOT/args" CCW_TEST_EXIT=0 CLAUDE_CODE_SIMPLE=inherited \
  "$ROOT/ccw" --ds --model sonnet -p 'two words' >/dev/null)
assert_eq "$(cat "$TEST_ROOT/called")" "$TEST_ROOT/bin/claude" "default Claude executable"
assert_eq "$(cat "$TEST_ROOT/base")" "https://ds.example.invalid" "provider environment loaded"
assert_eq "$(cat "$TEST_ROOT/model")" "ds-model" "provider model loaded"
assert_eq "$(cat "$TEST_ROOT/key")" "test-key-value" "key environment loaded"
assert_eq "$(cat "$TEST_ROOT/simple")" "" "inherited CLAUDE_CODE_SIMPLE cleared"
assert_eq "$(cat "$TEST_ROOT/args")" $'--model\nsonnet\n-p\ntwo words' "argument forwarding"

# --simple and CCW_SIMPLE both set the upstream Claude Code variable.
(cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" CCW_CONFIG_DIR= \
  PATH="$TEST_ROOT/bin:$PATH" CCW_TEST_CALLED="$TEST_ROOT/called" CCW_TEST_BASE_URL="$TEST_ROOT/base" \
  CCW_TEST_MODEL="$TEST_ROOT/model" CCW_TEST_API_KEY="$TEST_ROOT/key" CCW_TEST_SIMPLE="$TEST_ROOT/simple" \
  CCW_TEST_ARGS="$TEST_ROOT/args" "$ROOT/ccw" --ds --simple >/dev/null)
assert_eq "$(cat "$TEST_ROOT/simple")" "1" "--simple sets CLAUDE_CODE_SIMPLE"
(cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" CCW_CONFIG_DIR= \
  PATH="$TEST_ROOT/bin:$PATH" CCW_SIMPLE=1 CCW_TEST_CALLED="$TEST_ROOT/called" \
  CCW_TEST_BASE_URL="$TEST_ROOT/base" CCW_TEST_MODEL="$TEST_ROOT/model" CCW_TEST_API_KEY="$TEST_ROOT/key" \
  CCW_TEST_SIMPLE="$TEST_ROOT/simple" CCW_TEST_ARGS="$TEST_ROOT/args" "$ROOT/ccw" --ds >/dev/null)
assert_eq "$(cat "$TEST_ROOT/simple")" "1" "CCW_SIMPLE sets CLAUDE_CODE_SIMPLE"

# CCW_CLAUDE_BIN override and child exit code are respected.
(cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" CCW_CONFIG_DIR= \
  CCW_CLAUDE_BIN="$TEST_ROOT/bin/claude-custom" CCW_TEST_CALLED="$TEST_ROOT/called" \
  CCW_TEST_BASE_URL="$TEST_ROOT/base" CCW_TEST_MODEL="$TEST_ROOT/model" CCW_TEST_API_KEY="$TEST_ROOT/key" \
  CCW_TEST_SIMPLE="$TEST_ROOT/simple" CCW_TEST_ARGS="$TEST_ROOT/args" CCW_TEST_EXIT=23 \
  "$ROOT/ccw" --ds >/dev/null 2>&1) && child_exit_code=0 || child_exit_code=$?
assert_eq "$child_exit_code" "23" "upstream exit status propagation"
assert_eq "$(cat "$TEST_ROOT/called")" "$TEST_ROOT/bin/claude-custom" "CCW_CLAUDE_BIN override"

# The installer creates aliases and private config directories outside the repository.
INSTALL_DIR="$TEST_ROOT/install/bin"
INSTALL_CONFIG="$TEST_ROOT/install/config/ccw"
mkdir -p "$INSTALL_DIR"
CCW_CONFIG_DIR="$INSTALL_CONFIG" "$ROOT/install.sh" "$INSTALL_DIR" >/dev/null
[[ -d "$INSTALL_CONFIG/providers" && -d "$INSTALL_CONFIG/keys" ]] || fail "installer must create configured provider/key directories"
assert_eq "$(stat -f '%Lp' "$INSTALL_CONFIG")" "700" "config root permissions"
assert_eq "$(stat -f '%Lp' "$INSTALL_CONFIG/providers")" "700" "providers directory permissions"
assert_eq "$(stat -f '%Lp' "$INSTALL_CONFIG/keys")" "700" "keys directory permissions"
CUSTOM_XDG="$TEST_ROOT/custom-xdg"
XDG_CONFIG_HOME="$CUSTOM_XDG" "$ROOT/install.sh" "$TEST_ROOT/xdg-bin" >/dev/null
[[ -d "$CUSTOM_XDG/ccw/providers" && -d "$CUSTOM_XDG/ccw/keys" ]] || fail "installer must honor XDG_CONFIG_HOME"
EXISTING_CONFIG="$TEST_ROOT/existing-config"
mkdir -p "$EXISTING_CONFIG/providers" "$EXISTING_CONFIG/keys"
chmod 755 "$EXISTING_CONFIG" "$EXISTING_CONFIG/providers" "$EXISTING_CONFIG/keys"
CCW_CONFIG_DIR="$EXISTING_CONFIG" "$ROOT/install.sh" "$TEST_ROOT/existing-bin" >/dev/null
assert_eq "$(stat -f '%Lp' "$EXISTING_CONFIG")" "755" "existing config root permissions unchanged"
assert_eq "$(stat -f '%Lp' "$EXISTING_CONFIG/providers")" "755" "existing providers permissions unchanged"
assert_eq "$(stat -f '%Lp' "$EXISTING_CONFIG/keys")" "755" "existing keys permissions unchanged"
[[ ! -e "$ROOT/claude-wrapper" && ! -e "$ROOT/claude-code-wrapper" ]] || fail "aliases must not live in the repository"
for alias in claude-wrapper claude-code-wrapper; do
  [[ -L "$INSTALL_DIR/$alias" ]] || fail "$alias must be an installed symlink"
  assert_eq "$(readlink "$INSTALL_DIR/$alias")" "ccw" "$alias target"
  (cd "$TEST_ROOT/project/subdir" && env HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg" CCW_CONFIG_DIR= \
    PATH="$TEST_ROOT/bin:$PATH" CCW_TEST_CALLED="$TEST_ROOT/called" CCW_TEST_BASE_URL="$TEST_ROOT/base" \
    CCW_TEST_MODEL="$TEST_ROOT/model" CCW_TEST_API_KEY="$TEST_ROOT/key" CCW_TEST_SIMPLE="$TEST_ROOT/simple" \
    CCW_TEST_ARGS="$TEST_ROOT/args" "$INSTALL_DIR/$alias" --ds --help >/dev/null)
done
[[ ! -e "$ROOT/cclaude" ]] || fail "old cclaude executable must not remain"

# Removed no-op option fails clearly instead of being silently swallowed.
if output="$("$ROOT/ccw" --full-skills 2>&1)"; then
  fail "--full-skills must be rejected"
else
  assert_contains "$output" "has been removed" "removed --full-skills message"
fi

print -- "PASS: CCW config, migration boundary, forwarding, flags, and aliases"
