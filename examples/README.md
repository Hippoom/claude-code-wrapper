# Example Configurations

Copy these files to your config directory and edit them with your own settings.

## Quick Start

```bash
# Create config directory
mkdir -p ~/.config/cclaude/providers ~/.config/cclaude/keys

# Add a provider (e.g. DeepSeek)
cp ds.example.sh ~/.config/cclaude/providers/ds.sh

# Add an API key
cp ds-default-key.example.sh ~/.config/cclaude/keys/ds-default.sh

# Make sure permissions are secure
chmod 600 ~/.config/cclaude/keys/*.sh

# Edit the files with your real API key and model names
vim ~/.config/cclaude/providers/ds.sh
vim ~/.config/cclaude/keys/ds-default.sh
```

## File Naming

- **Provider files**: `<name>.sh` — the name becomes the provider shortcut (e.g. `--ds`)
- **Key files**: `<name>.sh` — the name is referenced via `.claude-provider` or `--provider` flag
