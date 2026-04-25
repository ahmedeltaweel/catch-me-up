---
description: Get a summary of recent activity across GitHub repos, Slack channels, and Confluence pages
argument-hint: "[time-range, e.g. 2d, 1w — default: 1d]"
allowed-tools: [Bash, Read, Glob, Grep, Agent, mcp__plugin_slack_slack__*]
---

# Catch Me Up — Activity Summary

Generate a comprehensive activity summary across GitHub repositories, Slack channels, and Confluence spaces.

## Step 0: Parse Time Range

The user provided: `$ARGUMENTS`

Parse the time range argument:
- If empty or blank, default to `1d` (last 24 hours)
- Supported formats: `Nd` (days), `Nw` (weeks). Examples: `1d`, `4d`, `1w`, `2w`
- Convert weeks to days (1w = 7d, 2w = 14d)

Compute the cutoff date. On macOS use:
```bash
date -v-<N>d +%Y-%m-%d
```
On Linux use:
```bash
date -d "<N> days ago" +%Y-%m-%d
```

Store these values mentally for use in all subsequent steps:
- `SINCE_DATE`: YYYY-MM-DD format
- `SINCE_ISO`: YYYY-MM-DDT00:00:00Z format (for GitHub API)
- `DAYS`: the number of days as an integer

## Step 1: Load Configuration

Read the configuration file that specifies which repos, channels, and Confluence spaces to monitor.

Search for the config file in this order (use the first one found):
1. `./catch-me-up.yaml` (current project directory)
2. `~/.config/catch-me-up/config.yaml` (user global config)
3. `~/.catch-me-up.yaml` (user home fallback)

Run:
```bash
test -f catch-me-up.yaml && echo "FOUND: ./catch-me-up.yaml" || \
(test -f ~/.config/catch-me-up/config.yaml && echo "FOUND: ~/.config/catch-me-up/config.yaml" || \
(test -f ~/.catch-me-up.yaml && echo "FOUND: ~/.catch-me-up.yaml" || echo "NOT_FOUND"))
```

If NOT_FOUND, tell the user:
- They need to create a config file
- Point them to `catch-me-up.example.yaml` in the plugin directory for the format
- Stop here

Read the config file and extract:
- `github.repos` — list of org/repo strings
- `slack.channels` — list of channel names
- `confluence.page_ids` — list of Confluence page IDs to monitor

## Step 2: GitHub Activity

For EACH repository in `github.repos`:

### 2a. Recent Commits
First, get the list of commits:
```bash
gh api "repos/{owner}/{repo}/commits?since={SINCE_ISO}&per_page=50" \
  --jq '.[] | "\(.sha[0:7]) \(.commit.author.name) \(.commit.author.date[0:10]) \(.commit.message | split("\n") | .[0])"'
```

If a repo returns an error (404, permission denied), note it and continue.

Then, for each commit, fetch the diff to understand what actually changed:
```bash
gh api "repos/{owner}/{repo}/commits/{FULL_SHA}" \
  --jq '{files: [.files[] | {filename, status, additions, deletions, patch: .patch[0:500]}]}'
```

Use the diff/patch data to write a **brief 1-2 sentence summary** of what the commit actually does — go beyond the commit message. For example:
- "Adds retry logic with exponential backoff to the payment gateway client (3 files changed)"
- "Fixes null pointer in user lookup by adding a nil check before accessing profile fields"

Keep the per-commit summaries short but meaningful. If there are more than 15 commits, summarize the diffs only for the 15 most significant ones (by number of changes) and list the rest with just their commit messages.

### 2b. Pull Request Activity
```bash
gh pr list --repo {owner}/{repo} --state all \
  --search "updated:>={SINCE_DATE}" \
  --json number,title,state,author,createdAt,mergedAt,url \
  --limit 50
```

Categorize PRs into:
- **Opened**: created within the time range
- **Merged**: merged within the time range
- **Closed**: closed (not merged) within the time range
- **In Review**: still open with recent activity

### 2c. Compile GitHub Section
For each repo, summarize:
- Total commits with the most notable changes
- PR activity grouped by category
- If a repo had zero activity, say "No activity in the last N days"

## Step 3: Slack Activity

For EACH channel in `slack.channels`:

1. Use `slack_search_channels` to find the channel by name (strip any leading `#`)
2. Use `slack_read_channel` with a limit of 200 messages to get recent activity
3. For ALL threads that have replies, use `slack_read_thread` to read the full thread — threads often contain the most important context, decisions, and agreements

Summarize each channel with the following structure:

**Key Discussions & Context:**
For each significant conversation or topic, provide a detailed summary that includes:
- What was discussed and why
- Who was involved
- The full context — enough that someone who missed it completely can follow along
- How the discussion evolved (e.g., "X raised a concern, Y investigated, Z confirmed the fix")

**Decisions & Agreements:**
Explicitly call out any decisions or agreements reached. Include:
- What was decided
- Who agreed / approved / signed off
- Any conditions or caveats ("agreed to do X, but only after Y is done")
- Quote the key messages if the exact wording matters

**Action Items & Owners:**
- List any action items with who owns them
- Include deadlines if mentioned

**Announcements & Updates:**
- Notable announcements, releases, outages, or status updates

**Unresolved / Open Threads:**
- Discussions that are still ongoing or waiting for a response
- Questions that were asked but not yet answered

If a channel cannot be found, note it and continue. If a channel has no recent activity, mention when the last message was posted.

**Important**: Do NOT lose context. This summary is for someone who may have been away for days. Include enough detail that they can understand what happened, what was agreed, and what needs their attention — without needing to go read the channels themselves. Err on the side of more detail rather than less. Summarize thoroughly, don't just list topic names.

## Step 4: Confluence Activity

### 4a. Check acli is available
```bash
which acli && acli auth status 2>&1
```
If `acli` is not available or not authenticated, skip this section and tell the user to install and authenticate acli (`acli auth login`).

### 4b. Check each configured page

For EACH page ID in `confluence.page_ids`, fetch the page details with its content:
```bash
acli confluence page view --id {PAGE_ID} --json --include-version
```

Parse the JSON response:
- Check if the page's version `when` date falls within the time range (on or after SINCE_DATE)
- If the page was modified within the range, include it in the report
- If the page was NOT modified within the range, skip it silently
- If the page ID returns an error, note it and continue

### 4c. For each changed page, get the content to understand context

For pages that were modified, also fetch the page body to understand the page's purpose and what changed:
```bash
acli confluence page view --id {PAGE_ID} --json --body-format storage --include-version
```

If the page has multiple versions within the time range (version number increased by more than 1), also fetch the previous version to understand the diff:
```bash
acli confluence page view --id {PAGE_ID} --json --body-format storage --version {PREVIOUS_VERSION_NUMBER}
```

Compare the two versions to identify what specifically changed.

### 4d. Compile Confluence Section
For each page that was changed within the time range, provide:

**Page context**: A 1-2 sentence description of what this page is about based on its content (e.g., "This is the team's runbook for handling payment gateway outages" or "Architecture decision record for the migration to event-driven messaging")

**Change summary**: A detailed summary of what changed, based on comparing the content or reading the current version:
- What sections were added, removed, or modified
- The substance of the changes (not just "section 3 was updated" but "added a new troubleshooting step for handling timeout errors in the auth service")
- Who made the changes and when

**Metadata**:
- Page title as a clickable link (construct URL from the `_links.base` + `_links.webui` fields in the JSON, or use `https://deliveryhero.atlassian.net/wiki/pages/{PAGE_ID}`)
- Space name
- Modified by and date
- Version number and version comment if any

If no pages were modified in the time range, say "No Confluence changes detected in the last N days for the monitored pages."

## Step 5: Compose Report

Present the complete report in this format:

---

# Catch Me Up — {SINCE_DATE} to {TODAY}

## GitHub Activity

### {repo-name-1}
**Commits ({count}):**
- `abc1234` — Commit message (Author, date)
  _Adds retry logic with exponential backoff to the payment gateway client (3 files)_
- `def5678` — Commit message (Author, date)
  _Fixes null pointer in user lookup by adding nil check before accessing profile fields_
- ...

**Pull Requests:**
- :rocket: Merged: #{number} Title (author) — url
- :eyes: In Review: #{number} Title (author) — url
- :new: Opened: #{number} Title (author) — url

### {repo-name-2}
(same format)

---

## Slack Highlights

### #{channel-1}

**Key Discussions:**
- {Detailed summary of discussion with context, who was involved, how it evolved}

**Decisions & Agreements:**
- {What was decided, who agreed, any conditions}

**Action Items:**
- {Action item — Owner (deadline if mentioned)}

**Unresolved:**
- {Open questions or threads still waiting for response}

### #{channel-2}
(same format)

---

## Confluence Changes

### [Page Title](url)
**Space:** SPACE | **Modified by:** Author | **Date:** date | **Version:** N

**Page context:** _Brief description of what this page is about_

**What changed:** Summary of the actual content changes — sections added/removed/modified with substance of the changes

---

*Report generated on {TODAY}, covering activity since {SINCE_DATE} ({N} days)*

---

## Error Handling

- If a GitHub repo returns 404 or permission errors, note it in the report under that repo and continue
- If a Slack channel cannot be found, note it and continue with remaining channels
- If Confluence/acli is not available or returns errors, note the error and continue
- If an entire section has no config entries (e.g., no Slack channels listed), skip that section header entirely
- Always produce whatever partial report is possible rather than failing completely
- At the end, list any errors or skipped items in a "Notes" section
