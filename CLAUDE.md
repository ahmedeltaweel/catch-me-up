# catch-me-up Plugin

This plugin provides the `/catch-me-up` command that generates an activity summary
across GitHub repositories, Slack channels, and Confluence pages.

## Usage

- `/catch-me-up` — Summary for the last 24 hours
- `/catch-me-up 4d` — Summary for the last 4 days
- `/catch-me-up 1w` — Summary for the last week

## Configuration

The plugin reads from a YAML config file. See `catch-me-up.example.yaml` for the format.

Config file search order:
1. `./catch-me-up.yaml`
2. `~/.config/catch-me-up/config.yaml`
3. `~/.catch-me-up.yaml`

## Dependencies

- **GitHub**: `gh` CLI must be authenticated (`gh auth login`)
- **Slack**: Slack MCP plugin must be installed and authenticated
- **Confluence**: `acli` must be installed and authenticated (`acli auth login`)
