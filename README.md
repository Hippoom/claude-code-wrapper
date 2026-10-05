# CCW (Claude Code Wrapper)

**CCW** is a per-project wrapper around the `claude` command. It manages provider endpoints, model-tier mappings, and API keys without repeatedly exporting environment variables.

- `ccw` is the primary command.
- `claude-wrapper` and `claude-code-wrapper` are long-name aliases for the same launcher.
- CCW invokes Claude Code's `claude` executable by default and forwards its CLI arguments.
- Provider shortcuts such as `--ds` and `--gpt` select provider configuration; Claude Code's `--model` and `/model` select model tiers.

This is an independent community wrapper, not an official Anthropic product.

## Installation

```bash
git clone https://github.com/Hippoom/claude-code-wrapper.git
cd claude-code-wrapper
./install.sh
```

The installer copies the `ccw` launcher and creates the `claude-wrapper` and `claude-code-wrapper` symlink aliases in `~/bin`. Pass a destination directory to override it, for example `./install.sh "$HOME/.local/bin"`. Add the chosen directory to `PATH` if needed. You need `zsh` and the Claude Code CLI (`claude`) in your `PATH`.

The aliases are created in the installation directory, not stored in the repository.

You can set `CCW_CLAUDE_BIN` to invoke a different Claude Code executable. The default is `claude`.

## Quick Start

### 1. Create provider and key files

```bash
mkdir -p ~/.config/ccw/providers ~/.config/ccw/keys

cat > ~/.config/ccw/providers/my-provider.sh <<'EOF'
export ANTHROPIC_BASE_URL="https://api.example.com/anthropic"
export ANTHROPIC_MODEL="my-model"
export ANTHROPIC_DEFAULT_OPUS_MODEL="my-model"
export ANTHROPIC_DEFAULT_SONNET_MODEL="my-model"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="my-fast-model"
export ANTHROPIC_REASONING_MODEL="my-model"
EOF

cat > ~/.config/ccw/keys/my-key.sh <<'EOF'
export ANTHROPIC_API_KEY="sk-your-real-key-here"
EOF
chmod 600 ~/.config/ccw/keys/my-key.sh
```

Provider files define endpoint and model-tier mappings; key files hold credentials. Don't put real API keys in this repository.

### 2. Select the provider for a project

```bash
cd my-project
ccw --provider my-provider:my-key
```

This writes the key name to `.ccw` in the current directory. Subsequent launches discover it while walking up parent directories:

```bash
ccw --my-provider
ccw --my-provider --model haiku -p "explain this code"
```

You can also invoke either long-name alias:

```bash
claude-wrapper --my-provider
claude-code-wrapper --my-provider
```

## Usage

```text
ccw --provider <provider>:<key>    Select provider/key and save key name to .ccw
ccw --<provider>                   Select provider using .ccw
ccw --<provider>:<key>             Select provider and key inline
ccw --<provider> --model <tier>    Start with a Claude Code model tier
ccw --list                         List configured providers and keys
ccw --which                        Show resolved provider and key configuration
ccw --help                         Show help
```

Provider shortcuts come from files named `<config>/providers/<name>.sh`. The current examples include:

| Shortcut | Provider |
|----------|----------|
| `--ds` | DeepSeek — Pro and Flash model-tier mapping |
| `--gpt` | GPT via gateway (when configured) |

## Configuration

### Config directory

1. `CCW_CONFIG_DIR` — optional explicit config root.
2. `${XDG_CONFIG_HOME:-~/.config}/ccw` — default config root.

Both locations contain `providers/` and `keys/` subdirectories. The project key-selection marker is `.ccw` and stores one key filename stem.

CCW does not automatically read `~/.claude-profiles/`, `~/.config/cclaude/`, `.claude-provider`, or variables prefixed with `CCLAUDE_`.

### Provider file format and model tiers

Provider files export the `ANTHROPIC_*` variables Claude Code reads. For a provider with multiple model tiers, map the tiers to provider model IDs:

```bash
export ANTHROPIC_MODEL="provider-pro-model" # Default when CCW launches
export ANTHROPIC_DEFAULT_OPUS_MODEL="provider-pro-model"
export ANTHROPIC_DEFAULT_SONNET_MODEL="provider-pro-model"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="provider-fast-model"
export ANTHROPIC_REASONING_MODEL="provider-pro-model"
```

Select the tier at launch without changing provider, key, or endpoint:

```bash
ccw --ds                         # provider default
ccw --ds --model haiku           # fast / low-cost tier
ccw --ds --model sonnet          # balanced tier
ccw --ds --model opus            # strongest tier
```

In an interactive session, use `/model`. CCW forwards `--model` and all remaining arguments unchanged.

### Model context and effort (optional)

For provider models that Claude Code does not recognize, Claude Code may assume a 200k context window or not expose effort controls. Configure relevant upstream variables in that provider file only when needed:

```bash
export CLAUDE_CODE_MAX_CONTEXT_TOKENS="896000"
export CLAUDE_CODE_EFFORT_LEVEL="max"
export CLAUDE_CODE_ALWAYS_ENABLE_EFFORT="1"
```

These are Claude Code variables, not CCW-specific settings; their behavior depends on the provider and model.

### Skills and compatibility fallback

CCW loads the full local Claude Code environment, including Skills, plugins, hooks, and other customizations by default. If a custom provider requires reduced initialization, opt in for a launch with either:

```bash
ccw --<provider> --simple
CCW_SIMPLE=1 ccw --<provider>
```

`--simple` makes CCW set `CLAUDE_CODE_SIMPLE=1` and is consumed by the wrapper; it is not passed to Claude Code. Without it, CCW clears inherited `CLAUDE_CODE_SIMPLE` to retain default full initialization. `--full-skills` and the old `CCLAUDE_FULL_SKILLS` setting are unsupported; full Skills already load by default.

### Key files

A key file exports one upstream variable, for example:

```bash
export ANTHROPIC_API_KEY="sk-..."
```

Some providers use `ANTHROPIC_AUTH_TOKEN` instead. Protect key files with `chmod 600`.

## Breaking migration from cclaude

This rebrand is intentionally not backward-compatible. CCW never searches old configuration paths or accepts old wrapper environment variables. Before switching:

```bash
mkdir -p ~/.config/ccw/providers ~/.config/ccw/keys
cp -p ~/.claude-profiles/*.sh ~/.config/ccw/providers/
cp -p ~/.claude-profiles/keys/*.sh ~/.config/ccw/keys/
```

If you used the XDG `cclaude` directory instead, copy its `providers/` and `keys/` into `$XDG_CONFIG_HOME/ccw/`. Rename each project marker from `.claude-provider` to `.ccw`. Update `CCLAUDE_CONFIG_DIR` to `CCW_CONFIG_DIR`, `CCLAUDE_SIMPLE` to `CCW_SIMPLE`, and `CLAUDE_BIN` (if used) to `CCW_CLAUDE_BIN`. Install and invoke `ccw`; there is no `cclaude` command or alias.

## Repository

The source repository is [Hippoom/claude-code-wrapper](https://github.com/Hippoom/claude-code-wrapper). The short executable name is `ccw`; the repository uses the descriptive name for searchability.

## Security

- API keys are stored as plaintext shell variables; protect the keys directory with `chmod 600 ~/.config/ccw/keys/*.sh`.
- CCW warns about world-readable provider/key files.
- CCW clears inherited Anthropic provider variables before loading the selected provider/key to prevent cross-project leakage.

## License

MIT
