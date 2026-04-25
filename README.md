# catch-me-up

A Claude Code command that gives you a daily (or multi-day) summary of activity across your team's GitHub repos, Slack channels, and Confluence pages.

## What it does

Type `/catch-me-up` and get a structured report covering:
- **GitHub**: commits with code change summaries, PRs opened/merged/closed (bot PRs filtered by default)
- **Slack**: detailed channel summaries with decisions, agreements, action items, and full thread context
- **Confluence**: page and subpage change summaries with full context of what the page is about

All three sources are fetched **in parallel** using subagents for speed. The output is a single clean report with no intermediate logging.

## Installation

```bash
git clone https://github.com/ahmedeltaweel/catch-me-up.git
./catch-me-up/install.sh
```

This copies the command to `~/.claude/commands/` and creates a config file at `~/.config/catch-me-up/config.yaml`.

Restart Claude Code after installing.

## Setup

### 1. Edit your config file

```bash
$EDITOR ~/.config/catch-me-up/config.yaml
```

### 2. Authenticate GitHub

```bash
gh auth login
gh auth status  # verify
```

### 3. Install and authenticate Slack MCP plugin

The Slack MCP plugin handles channel summarization. Install it via Claude Code's plugin system. It will prompt for OAuth on first use.

### 4. Authenticate Atlassian CLI

```bash
acli auth login
acli auth status  # verify
```

To find Confluence page IDs: open a page in your browser and look at the URL — the numeric ID is in the path (e.g., `.../pages/12345678/Page+Title`). You can also find it via Page Info in the Confluence UI.

## Usage

```
/catch-me-up          # Last 24 hours
/catch-me-up 3d       # Last 3 days
/catch-me-up 1w       # Last week
```

## Config file format

```yaml
github:
  repos:
    - org/repo-name
  # Show Dependabot/Renovate bot PRs and commits (default: false)
  show_bot_prs: false

slack:
  channels:
    - channel-name

confluence:
  page_ids:
    - "12345678"
  # Recursively include all subpages (default: true)
  include_subpages: true
```

Config file is searched in this order:
1. `./catch-me-up.yaml` (current directory)
2. `~/.config/catch-me-up/config.yaml` (user global)
3. `~/.catch-me-up.yaml` (home fallback)

## Features

- **Parallel execution** — GitHub, Slack, and Confluence are fetched concurrently via subagents
- **Bot filtering** — Dependabot/Renovate PRs and commits excluded by default (`show_bot_prs: false`)
- **Subpage crawling** — Confluence recursively checks all child pages (`include_subpages: true`)
- **Commit diff summaries** — Each commit gets a 1-2 sentence summary based on the actual code diff
- **Thread-aware Slack** — All threads are read fully to capture decisions, agreements, and action items
- **Silent execution** — No intermediate logging, only the final formatted report
- **Zero-activity repos hidden** — Repos with no activity after filtering are omitted from the report

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Config not found | Run `install.sh` or create `~/.config/catch-me-up/config.yaml` |
| GitHub repo 404 | Check repo name and run `gh auth status` |
| Slack channel not found | Check spelling (no `#` prefix needed) |
| Slack wrong time window | Verify system date is correct (`date`) |
| Confluence errors | Run `acli confluence auth login` to re-authenticate |
| Duplicate repos in config | They are deduplicated automatically |
