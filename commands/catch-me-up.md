---
description: Get a summary of recent activity across GitHub repos, Slack channels, and Confluence pages
argument-hint: "[time-range, e.g. 2d, 1w — default: 1d]"
allowed-tools: [Bash, Read, Glob, Grep, Agent, mcp__plugin_slack_slack__*]
---

# Catch Me Up — Activity Summary

Generate a comprehensive activity summary across GitHub repositories, Slack channels, and Confluence spaces.

## CRITICAL: Output Discipline

**Be silent during work. Only output the final report.**

- Do NOT narrate what you are doing ("Let me check...", "Now fetching...", "Reading the config...")
- Do NOT show intermediate results, raw API output, or command output
- Do NOT explain your steps or reasoning
- The ONLY text you output to the user should be:
  1. A single brief status line before launching agents: `Catching you up on the last N days...`
  2. The final composed report (Step 3)
- If something fails (config not found, auth error), report that concisely — no preamble
- Agents work silently in the background — they should NOT output progress either

## Step 0: Parse Time Range

The user provided: `$ARGUMENTS`

Parse the time range argument:
- If empty or blank, default to `1d` (last 24 hours)
- Supported formats: `Nd` (days), `Nw` (weeks). Examples: `1d`, `4d`, `1w`, `2w`
- Convert weeks to days (1w = 7d, 2w = 14d)

Compute ALL timestamp formats upfront by running these commands:

On macOS:
```bash
SINCE_DATE=$(date -v-<N>d +%Y-%m-%d)
SINCE_UNIX=$(date -j -f "%Y-%m-%d" "$SINCE_DATE" "+%s")
echo "SINCE_DATE=$SINCE_DATE SINCE_UNIX=$SINCE_UNIX"
```

On Linux:
```bash
SINCE_DATE=$(date -d "<N> days ago" +%Y-%m-%d)
SINCE_UNIX=$(date -d "$SINCE_DATE" "+%s")
echo "SINCE_DATE=$SINCE_DATE SINCE_UNIX=$SINCE_UNIX"
```

Store these values for use in all subsequent steps:
- `SINCE_DATE`: YYYY-MM-DD format (for display and GitHub search queries)
- `SINCE_ISO`: `{SINCE_DATE}T00:00:00Z` (for GitHub API `since` parameter)
- `SINCE_UNIX`: Unix epoch seconds (for Slack API `oldest` parameter)
- `DAYS`: the number of days as an integer

## Step 1: Load Configuration

Read the configuration file. Search in this order (use the first one found):
1. `./catch-me-up.yaml`
2. `~/.config/catch-me-up/config.yaml`
3. `~/.catch-me-up.yaml`

```bash
test -f catch-me-up.yaml && echo "FOUND: ./catch-me-up.yaml" || \
(test -f ~/.config/catch-me-up/config.yaml && echo "FOUND: ~/.config/catch-me-up/config.yaml" || \
(test -f ~/.catch-me-up.yaml && echo "FOUND: ~/.catch-me-up.yaml" || echo "NOT_FOUND"))
```

If NOT_FOUND, tell the user they need to create a config file and stop.

Read the config file and extract (deduplicate any repeated entries):
- `github.repos` — list of org/repo strings (deduplicate before processing)
- `github.show_bot_prs` — boolean flag (default: `false`). When false, exclude PRs and commits authored by Dependabot, Renovate, or other dependency-update bots (author names containing "dependabot", "renovate", or "[bot]")
- `slack.channels` — list of channel names
- `confluence.page_ids` — list of Confluence page IDs to monitor
- `confluence.include_subpages` — boolean flag (default: `true`). When true, recursively include all child/subpages of the configured pages

After loading config, output exactly ONE status line to the user:

`Catching you up on the last {DAYS} day(s)...`

Then immediately launch agents. No other output until the final report.

## Step 2: Launch Parallel Agents

**IMPORTANT**: Launch the following 3 agents IN PARALLEL using the Agent tool in a SINGLE message. These are completely independent data sources and must run concurrently to save time. Do NOT run them sequentially.

Pass each agent the computed `SINCE_DATE`, `SINCE_ISO`, `SINCE_UNIX`, `DAYS` values and the relevant config section. Each agent should return its section of the report as formatted markdown.

If a config section is empty (e.g., no slack channels), skip that agent entirely.

---

### Agent 1: GitHub Activity

Launch an Agent with this prompt (include the actual values, not placeholders):

```
You are generating the GitHub section of a catch-me-up report. Work silently — do NOT output progress or narration, only return the final formatted markdown.

SINCE_DATE: {SINCE_DATE}
SINCE_ISO: {SINCE_ISO}
DAYS: {DAYS}
show_bot_prs: {true/false from config}

Repos to check:
{list each repo from config}

Deduplicate the repo list before processing.

For EACH repository:

1. Get recent commits:
   gh api "repos/{owner}/{repo}/commits?since={SINCE_ISO}&per_page=50" \
     --jq '.[] | "\(.sha) \(.commit.author.name) \(.commit.author.date[0:10]) \(.commit.message | split("\n") | .[0])"'

2. Bot filtering FIRST (before fetching diffs to save API calls): If show_bot_prs is false, immediately exclude commits where the author name contains "dependabot", "renovate", or "[bot]" (case-insensitive). If ALL commits are bot-authored, skip to step 4 — do NOT fetch diffs for bot commits.

3. Only for non-bot commits, fetch the diff:
   gh api "repos/{owner}/{repo}/commits/{FULL_SHA}" \
     --jq '{files: [.files[] | {filename, status, additions, deletions, patch: .patch[0:500]}]}'

   Write a brief 1-2 sentence summary of what the commit actually does based on the diff. Go beyond the commit message. If there are more than 15 commits, summarize diffs only for the 15 most significant ones and list the rest with just their commit messages.

4. Get PR activity:
   gh pr list --repo {owner}/{repo} --state all \
     --search "updated:>={SINCE_DATE}" \
     --json number,title,state,author,createdAt,mergedAt,url \
     --limit 50

5. Bot filtering: If show_bot_prs is false, exclude PRs where author.login contains "dependabot", "renovate", or "[bot]".

6. Categorize remaining PRs into: Opened, Merged, Closed, In Review.

7. If a repo has 0 commits AND 0 PRs after filtering, omit it entirely.

8. If a repo returns errors (404, permission denied), note the error and continue.

Return ONLY the formatted GitHub section as markdown, nothing else. Use this format per active repo:

### `{owner}/{repo-name}`

#### Commits ({count})

| Commit | Author | Date | Summary |
|--------|--------|------|---------|
| `abc1234` | @author | YYYY-MM-DD | _summary_ |

#### Pull Requests

> **Merged**
> - `#123` [PR Title](url) — @author

> **In Review**
> - `#125` [PR Title](url) — @author

> **Opened**
> - `#127` [PR Title](url) — @author

Use --- between repos. If no repos have activity, return "No GitHub activity in the last {DAYS} days."
```

---

### Agent 2: Slack Activity

Launch an Agent with this prompt (include actual values):

```
You are generating the Slack section of a catch-me-up report. Work silently — do NOT output progress or narration, only return the final formatted markdown.

SINCE_DATE: {SINCE_DATE}
SINCE_UNIX: {SINCE_UNIX}
DAYS: {DAYS}

Channels to summarize:
{list each channel from config}

For EACH channel:

1. Use slack_search_channels to find the channel by name (strip any leading #)
2. Use slack_read_channel with limit: 200 AND oldest: {SINCE_UNIX} — the oldest parameter is a Unix timestamp that filters messages to only those after the cutoff date. This is CRITICAL for getting the right time window.
3. VALIDATE: After reading messages, verify that the returned messages have timestamps within the expected date range (on or after SINCE_DATE). If messages appear to be from the wrong time period, flag this in the output.
4. For ALL threads that have replies, use slack_read_thread to read the full thread — threads contain the most important context, decisions, and agreements

Summarize each channel with this structure:

### #channel-name

#### Key Discussions
> **Topic: {topic title}**
> {Detailed summary with context — who was involved, what was discussed, how it evolved}

#### Decisions & Agreements
> - {What was decided} — agreed by **@person1**, **@person2** *(conditions if any)*
> Quote key messages if the exact wording matters.

#### Action Items
| Action | Owner | Deadline |
|--------|-------|----------|
| {action item} | @owner | {date or TBD} |

#### Unresolved
> - {Open question or thread waiting for response}

Rules:
- Do NOT lose context. This is for someone who may have been away for days. Include enough detail that they can understand what happened, what was agreed, and what needs their attention without reading the channels themselves.
- Err on the side of more detail rather than less.
- Omit empty subsections (e.g., no action items → skip that header).
- If a channel cannot be found, note it and continue.
- If a channel has no recent activity, mention when the last message was posted.
- Use --- between channels.

Return ONLY the formatted Slack section as markdown, nothing else.
```

---

### Agent 3: Confluence Activity

Launch an Agent with this prompt (include actual values):

```
You are generating the Confluence section of a catch-me-up report. Work silently — do NOT output progress or narration, only return the final formatted markdown.

SINCE_DATE: {SINCE_DATE}
DAYS: {DAYS}
include_subpages: {true/false from config}

Page IDs to check:
{list each page_id from config}

Before starting, verify acli Confluence connectivity with an actual API call (not just auth status, which can show partial auth):
  acli confluence space list --limit 1 --json 2>&1
If this fails, return an error note saying Confluence is not authenticated and suggest running: acli confluence auth login

Step 1: Build the full page list.

For EACH page ID, fetch the page and its children:
  acli confluence page view --id {PAGE_ID} --json --include-version --include-direct-children

If include_subpages is true (the default), collect child page IDs and recursively fetch their children too:
  acli confluence page view --id {CHILD_PAGE_ID} --json --include-version --include-direct-children

Repeat until no more children are found. Collect all page IDs (root + descendants).

Step 2: Check each page for changes.

For each page, check if the version "when" date is on or after SINCE_DATE.
- Modified → include in report
- Not modified → skip silently
- Error → note and continue

Step 3: For changed pages, get content.

Fetch the page body:
  acli confluence page view --id {PAGE_ID} --json --body-format storage --include-version

If the page has multiple versions within the range, also fetch the previous version:
  acli confluence page view --id {PAGE_ID} --json --body-format storage --version {PREVIOUS_VERSION_NUMBER}

Compare versions to identify what changed.

Step 4: Format each changed page as:

### [{Page Title}](url)
> **Space:** {SPACE} | **Modified by:** {Author} | **Date:** {date} | **Version:** {N}

**What this page is about:**
> _{1-2 sentence context based on content}_

**What changed:**
> - {Specific content changes with substance}

If the page is a subpage, add:
> _Subpage of: [{Parent Page Title}](parent-url)_

Rules:
- Construct URL from _links.base + _links.webui, or use https://deliveryhero.atlassian.net/wiki/pages/{PAGE_ID}
- If acli is not available or not authenticated, return an error note.
- Use --- between pages.
- If no pages were modified, return "No Confluence changes in the last {DAYS} days for the monitored pages."

Return ONLY the formatted Confluence section as markdown, nothing else.
```

---

## Step 3: Collect Results and Compose Report

Wait for all 3 agents to complete. Collect their markdown output and assemble the final report using the template below.

**Output ONLY the report below. No preamble, no "Here's the report", no trailing commentary.**

---

```
═══════════════════════════════════════════════════════════════
```

# Catch Me Up

> **{SINCE_DATE}** → **{TODAY}** · _{DAYS} day(s)_

```
═══════════════════════════════════════════════════════════════
```

## GitHub Activity

{Insert Agent 1's output here}

If Agent 1 returned no activity or was skipped, omit this entire section.

```
───────────────────────────────────────────────────────────────
```

## Slack Highlights

{Insert Agent 2's output here}

If Agent 2 returned no activity or was skipped, omit this entire section.

```
───────────────────────────────────────────────────────────────
```

## Confluence Changes

{Insert Agent 3's output here}

If Agent 3 returned no activity or was skipped, omit this entire section.

```
───────────────────────────────────────────────────────────────
```

If **any** agent reported errors, add:

## Notes

> {Error or skipped item with explanation}

```
═══════════════════════════════════════════════════════════════
```

> _Report generated on **{TODAY}** · Covering **{DAYS}** day(s) since **{SINCE_DATE}**_

---

## Formatting Rules

- Use `═══` double lines for major report boundaries (top, bottom)
- Use `───` single lines between the 3 main sections (GitHub, Slack, Confluence)
- Use `---` (horizontal rules) between items within a section (between repos, channels, pages)
- Use **bold** for names, decisions, repo names, and key terms
- Use _italic_ for context descriptions, summaries, and supplementary info
- Use `code` for commit SHAs, PR numbers, repo paths, and commands
- Use blockquotes (`>`) to create visual cards for grouped information
- Use tables for structured data (commits, action items)
- Omit empty subsections — if a channel has no action items, don't show the header
- Omit entire sections if the config had no entries for that source or the agent returned nothing

## Error Handling

- If a GitHub repo returns 404 or permission errors, note it in the Notes section and continue
- If a Slack channel cannot be found, note it in Notes and continue
- If Confluence/acli is not available or returns errors, note it in Notes and continue
- Always produce whatever partial report is possible rather than failing completely
