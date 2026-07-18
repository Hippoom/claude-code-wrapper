# cclaude

**Per-project Claude Code launcher** — manage multiple providers and API keys without environment variable chaos.

## Motivation

Claude Code reads `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL` from environment variables. If you work across multiple projects that use different providers or models, you end up constantly re-exporting env vars. `cclaude` solves this with a simple file-based config system:

- Each project stores which key to use in `.claude-provider`
- Provider settings and API keys live in separate files under `~/.config/cclaude/`
- A few shortcuts (`--ds-pro`, `--ds-flash`, `--gpt`) switch between providers instantly

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

# All args pass through to claude
cclaude --my-provider -p "explain this code"
```

## Usage

```
cclaude --provider <provider>:<key>    Full explicit (saves key)
cclaude --<provider>                   Shortcut (reads key from .claude-provider)
cclaude --<provider>:<key>             Shortcut with inline key switch
cclaude --list                         List available providers and keys
cclaude --which                        Show resolved config for current project
cclaude --help                         Show help
```

### Provider Shortcuts

Add a provider file at `<config>/providers/<name>.sh` and it becomes available as `--<name>`. The user's current setup includes:

| Shortcut | Provider |
|----------|----------|
| `--ds-pro` | DeepSeek Pro |
| `--ds-flash` | DeepSeek Flash (fast/cheap) |
| `--gpt` | GPT via gateway |

## Configuration

### Config Directory Priority

1. **`$CCLAUDE_CONFIG_DIR`** — env var override (takes full control)
2. **`~/.claude-profiles/`** — legacy path (detected automatically)
3. **`~/.config/cclaude/`** — XDG default (`$XDG_CONFIG_HOME/cclaude`)

Inside the config directory:

```
<config>/
├── providers/
│   ├── ds-pro.sh       →  --ds-pro
│   ├── ds-flash.sh     →  --ds-flash
│   └── gpt.sh          →  --gpt
└── keys/
    ├── default.sh      →  referenced from .claude-provider
    └── project-x.sh    →  per-project keys
```

### Provider File Format

A provider file exports the `ANTHROPIC_*` environment variables that Claude Code uses. Any variable you don't set is simply left unset — Claude Code uses its own defaults for those.

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
