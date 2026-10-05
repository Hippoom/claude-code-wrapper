# Example Configurations

Copy the provider and key examples into your CCW config directory, then replace placeholders with your own settings.

## Quick Start

```bash
mkdir -p ~/.config/ccw/providers ~/.config/ccw/keys

cp ds.example.sh ~/.config/ccw/providers/ds.sh
cp ds-default-key.example.sh ~/.config/ccw/keys/ds-default.sh
chmod 600 ~/.config/ccw/keys/*.sh

# Edit provider settings and add your real API key locally.
$EDITOR ~/.config/ccw/providers/ds.sh
$EDITOR ~/.config/ccw/keys/ds-default.sh
```

In your project directory, run `ccw --provider ds:ds-default` once to create the `.ccw` selection marker. Later, `ccw --ds` reads that key name. The installer also places the `claude-wrapper` and `claude-code-wrapper` command aliases beside `ccw`.

## File Naming

- **Provider files:** `<name>.sh`; the name becomes the provider shortcut (for example, `--ds`).
- **Key files:** `<name>.sh`; the stem is referenced via `.ccw` or `--provider <provider>:<key>`.

Use the documented XDG root `${XDG_CONFIG_HOME:-~/.config}/ccw`, or set `CCW_CONFIG_DIR` to a custom config root. Keep real provider credentials out of version control.
