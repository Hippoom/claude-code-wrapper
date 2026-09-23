# cclaude

**Per-project Claude Code launcher** — manage multiple providers and API keys without environment variable chaos.

## Motivation

Claude Code reads `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL` from environment variables. If you work across multiple projects that use different providers or models, you end up constantly re-exporting env vars. `cclaude` solves this with a simple file-based config system:

- Each project stores which key to use in `.claude-provider`
- Provider settings and API keys live in separate files under `~/.config/cclaude/`
- Provider shortcuts (for example, `--ds` and `--gpt`) switch endpoint and authentication; model tiers are selected with Claude Code’s `--model` flag or `/model`.

## Installation

```bash
# Clone the repo
git clone https://github.com/Hippoom/cclaude.git
cd cclaude

# Add to your PATH (pick one)
ln -s "$PWD/cclaude" /usr/local/bin/cclaude          # system-wide
ln -s "$PWD/cclaude" ~/bin/cclaude                    # user-only
```

**Requires:** `zsh` (for the script itself) and `claude` (the Claude Code CLI) in your PATH.

## Quick Start

### 1. Set up a provider

```bash
# Create config directories
mkdir -p ~/.config/cclaude/providers ~/.config/cclaude/keys

# Create a provider file (see examples/ for templates)
cat > ~/.config/cclaude/providers/my-provider.sh << 'EOF'
# Profile: My Provider
export ANTHROPIC_BASE_URL="https://api.example.com/anthropic"
export ANTHROPIC_MODEL="my-model"
export ANTHROPIC_DEFAULT_OPUS_MODEL="my-model"
export ANTHROPIC_DEFAULT_SONNET_MODEL="my-model"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="my-fast-model"
export ANTHROPIC_REASONING_MODEL="my-model"
EOF
```

### 2. Set up an API key

```bash
cat > ~/.config/cclaude/keys/my-key.sh << 'EOF'
# Key: My API Key
export ANTHROPIC_API_KEY="sk-your-real-key-here"
EOF

# Secure the key file
chmod 600 ~/.config/cclaude/keys/*.sh
```

### 3. Use it

```bash
# First time — explicit provider and key
cd my-project
cclaude --provider my-provider:my-key

# Later — just the shortcut
cclaude --my-provider

# All other Claude Code options pass through unchanged
cclaude --my-provider --model haiku -p "explain this code"
```

## Usage

```
cclaude --provider <provider>:<key>    Full explicit (saves key)
cclaude --<provider>                   Dynamic shortcut (reads key from .claude-provider)
cclaude --<provider>:<key>             Dynamic shortcut with inline key switch
cclaude --<provider> --model <tier>    Start with a Claude Code model tier
cclaude --list                         List available providers and keys
cclaude --which                        Show resolved config for current project
cclaude --help                         Show help
```

### Provider Shortcuts

Add a provider file at `<config>/providers/<name>.sh` and it becomes available as `--<name>`. The user's current setup includes:

| Shortcut | Provider |
|----------|----------|
| `--ds` | DeepSeek — Pro and Flash model-tier mapping |
| `--gpt` | GPT via gateway (when configured) |

## Configuration

### Config Directory Priority

1. **`$CCLAUDE_CONFIG_DIR`** — env var override (takes full control)
2. **`~/.claude-profiles/`** — legacy path (detected automatically)
3. **`~/.config/cclaude/`** — XDG default (`$XDG_CONFIG_HOME/cclaude`)

Inside the config directory:

```
<config>/
├── providers/
│   ├── ds.sh           →  --ds
│   └── gpt.sh          →  --gpt
└── keys/
    ├── default.sh      →  referenced from .claude-provider
    └── project-x.sh    →  per-project keys
```

### Provider File Format

A provider file exports the `ANTHROPIC_*` environment variables that Claude Code uses. It represents an endpoint and its supported model-tier mapping—not a single model. Any variable you don't set is simply left unset, so Claude Code uses its own defaults.

For a provider that supports multiple tiers, set a default startup model plus the tier mappings:

```bash
export ANTHROPIC_MODEL="provider-pro-model"                 # default on launch
export ANTHROPIC_DEFAULT_OPUS_MODEL="provider-pro-model"
export ANTHROPIC_DEFAULT_SONNET_MODEL="provider-pro-model"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="provider-fast-model"
export ANTHROPIC_REASONING_MODEL="provider-pro-model"
```

Then select a model tier without changing provider, key, or endpoint:

```bash
cclaude --ds                         # provider default
cclaude --ds --model haiku           # fast / low-cost tier
cclaude --ds --model sonnet          # balanced tier
cclaude --ds --model opus            # strongest tier
```

In an interactive Claude Code session, use `/model` to switch tiers. `cclaude` passes `--model` and every other remaining CLI argument through unchanged.

### Model Context and Effort (Optional)

A provider whose models Claude Code doesn't recognize (custom gateway IDs) is treated as a 200k-context model and won't receive an effort parameter. Two optional variables in the provider file override this:

```bash
# Cap Claude Code's auto-compact context for an unrecognized model.
# Without this, unrecognized models default to 200k.
export CLAUDE_CODE_MAX_CONTEXT_TOKENS="896000"

# Default thinking effort: low | medium | high | xhigh | max | auto.
# Only persistable via env var — the settings key accepts up to xhigh.
export CLAUDE_CODE_EFFORT_LEVEL="max"

# Force-send the effort parameter to models Claude Code doesn't recognize
# as effort-capable (third-party / gateway models).
export CLAUDE_CODE_ALWAYS_ENABLE_EFFORT="1"
```

Set these only where the provider needs them; a model Claude Code already recognizes from its catalog uses its own known context window and effort support.

### Skills and Custom-Provider Compatibility Mode

`cclaude` loads the complete local Claude Code environment by default, including locally installed Skills, plugins, hooks, and other customizations. It explicitly clears any inherited `CLAUDE_CODE_SIMPLE` value so launching through `cclaude` has the same local Skill-loading behavior as launching `claude` directly.

Some custom providers may require reduced initialization. If a provider fails under the default behavior, opt in to the compatibility fallback for that launch:

```bash
cclaude --<provider> --simple
# or
CCLAUDE_SIMPLE=1 cclaude --<provider>
```

Simple mode sets `CLAUDE_CODE_SIMPLE=1` and can suppress local Skills and other customizations. `--simple` is consumed by `cclaude` and is not forwarded to Claude Code. It changes only this environment-variable behavior; it does not change `HOME`, the working directory, provider/key selection, or the model mapping.

For compatibility with the earlier experiment, `--full-skills` and `CCLAUDE_FULL_SKILLS=1` remain accepted but are now no-op aliases: full Skills are already the default.

To verify a provider, start a **new** session from a real project directory (not your home directory or a Skill source directory), then run `/reload-skills`:

```bash
# Default: complete local Skills are loaded
cclaude --gpt

# Fallback only if the custom provider has an initialization compatibility issue
cclaude --gpt --simple
```

Compare the discovered Skill count and verify that `/slide` is available in the default mode. To roll back from simple mode, omit `--simple` or unset `CCLAUDE_SIMPLE`.

### Key File Format

A key file exports one variable:

```bash
export ANTHROPIC_API_KEY="sk-..."
```

You can also use `ANTHROPIC_AUTH_TOKEN` if your provider uses token-based auth.

### Per-Project Key (`.claude-provider`)

When you call `cclaude --provider <p>:<k>`, it writes the key name to `.claude-provider` in the current directory. Subsequent calls with just the shortcut read this file to know which key to use. The file contains a single line with the key name:

```
my-key
```

The walk-up search: if not found in the current directory, `cclaude` walks up to parent directories (like `.git` conventions).

## Security

- **API keys are stored as shell variables in plaintext** — protect the keys directory: `chmod 600 ~/.config/cclaude/keys/*.sh`
- `cclaude` will warn if it detects world-readable config files
- The script unsets all `ANTHROPIC_*` env vars before loading new config, preventing cross-project leakage

## License

MIT
