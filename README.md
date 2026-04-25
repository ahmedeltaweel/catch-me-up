# catch-me-up

A Claude Code plugin that gives you a daily (or multi-day) summary of activity across your team's GitHub repos, Slack channels, and Confluence pages.

## What it does

Type `/catch-me-up` and get a structured report covering:
- **GitHub**: commits, PRs opened/merged/closed, review activity
- **Slack**: channel summaries with key topics, decisions, and action items
- **Confluence**: recently modified pages with change details

## Installation

```bash
claude plugin add /path/to/catch-me-up
```

Or if shared via git:
```bash
git clone https://github.com/<your-org>/catch-me-up.git
claude plugin add ./catch-me-up
```

## Setup

### 1. Create your config file

```bash
# Copy the example and customize it
mkdir -p ~/.config/catch-me-up
cp /path/to/catch-me-up/catch-me-up.example.yaml ~/.config/catch-me-up/config.yaml
```

Edit `~/.config/catch-me-up/config.yaml` with your repos, channels, and page IDs.

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

slack:
  channels:
    - channel-name

confluence:
  page_ids:
    - "12345678"
```

Config file is searched in this order:
1. `./catch-me-up.yaml` (current directory)
2. `~/.config/catch-me-up/config.yaml` (user global)
3. `~/.catch-me-up.yaml` (home fallback)

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Config not found | Create `catch-me-up.yaml` — see `catch-me-up.example.yaml` |
| GitHub repo 404 | Check repo name and run `gh auth status` |
| Slack channel not found | Check spelling (no `#` prefix needed) |
| Confluence errors | Run `acli auth status` and re-login if needed |
