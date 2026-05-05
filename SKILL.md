---
name: ecosystem-update
description: Daily self-improvement loop — scans configured sources for new patterns, diffs against current setup, implements Quick Wins, writes a dated report. Reads sources.yaml + config.yaml. Use --dry-run for report only.
---

# Ecosystem Update

Scan configured sources for new patterns, diff against the current setup, implement Quick Wins, and write a dated report.

**Default (loop-safe):** `/ecosystem-update` — backs up, implements Quick Wins, writes report
**Report only:** `/ecosystem-update --dry-run` — fetches and scores but makes no changes

**Output:** `${config.paths.report_dir}/YYYY-MM-DD.md`

The skill is headless-safe: no interactive prompts, deterministic exit, idempotent on same-day reruns.

---

## Step 0 — Load Config

Read the skill's local config first:

1. `${SKILL_DIR}/sources.yaml` — the URLs to scan, organized into tiers
2. `${SKILL_DIR}/config.yaml` — paths, scoring weights, hard limits

If `sources.yaml` doesn't exist, fall back to `sources.example.yaml` and warn the user once.
If `config.yaml` doesn't exist, fall back to `config.example.yaml`.

`${SKILL_DIR}` is the directory this `SKILL.md` lives in (typically `~/.claude/skills/ecosystem-update/`).

---

## Step 1 — Read Current State

Before fetching anything external, snapshot the current config so you can diff against it.

The exact files to read are configured in `config.yaml::current_state_files`. Defaults:

1. `~/.claude/CLAUDE.md` — constitutional policy
2. `~/.claude/settings.json` — hooks, permissions, MCPs, plugins
3. Glob `~/.claude/agents/*.md` — agent frontmatter (name, tools, model, isolation)
4. Glob `~/.claude/skills/*/SKILL.md` — installed skill names + descriptions
5. Read `${config.paths.state_file}` — the `seen_items` array contains identifiers of previously reported items; skip any candidate whose identifier appears here

If a configured memory MCP is available (claude-mem, omni-mem, etc.), additionally search it for prior `ecosystem-update seen` observations as a secondary dedup signal.

Build an internal "already have" list dynamically from these reads. Do not hardcode specific items — derive from current file state.

---

## Step 2 — Fetch Sources

Iterate over `sources.yaml` tiers. Run `WebSearch` and `WebFetch` in parallel where possible.

### Tier 1 — Always fetch

For each entry in `tier_1_daily`, fetch the URL and extract per the entry's `extract` description.

### Tier 2 — Daily, but skippable

Skip the entire tier if `state_file.tier2_last_run` is within the last 24 hours.

### Tier 3 — Weekly

Skip the entire tier if `state_file.tier3_last_run` is within the last 7 days.

Custom tiers (`tier_4_monthly`, `tier_5_quarterly`, etc.) declared in `sources.yaml` follow the same skip-window pattern, with windows defined in the source entry.

### WebSearch supplements

If a source entry includes a `websearch_supplement` query, run that query in parallel with the main fetch. Use the search results as an additional candidate stream for that source.

---

## Step 3 — Extract Candidates

For each source, extract discrete items. Each candidate must have:

- **Title** — short name
- **Source** — URL or repo
- **Type** — one of the types declared in `config.yaml::candidate_types` (defaults: `hook`, `agent-pattern`, `skill`, `claude-md`, `mcp`, `research`)
- **Description** — what it does, one sentence
- **Slug** — kebab-case version of the title for dedup (e.g. `permission-request-hook`)

The candidate types and their detection criteria are configurable. Default detection logic:

**Hooks:** New hook events not in `settings.json` (e.g. PostCompact, PermissionRequest, `once: true` modifiers, `type: prompt` hooks, statusMessage, shell output injection via `!command`). Diff against current `settings.json` hook events.

**Agent patterns:** `isolation: worktree`, `context: fork`, `allowed-tools` wildcards, `argument-hint`, per-agent model overrides, tool restriction patterns. Diff against current `agents/*.md` frontmatter.

**Skills:** Domain-specific skills worth adapting. Diff against `skills/` directory listing.

**CLAUDE.md patterns:** `@import` for modular rules, keyword-routing tables, instinct scoring, prune/dream cycles. Diff against current CLAUDE.md.

**MCP servers:** New MCP integrations with clear utility. Diff against `settings.json::mcpServers`.

**Research:** Papers with directly applicable patterns. Only include if directly applicable to the current setup (per the philosophy gate at Step 5).

To customize detection for a non-Claude ecosystem, override these in `config.yaml::candidate_types`.

---

## Step 4 — Diff and Classify

For each candidate, assign one bucket:

- **HAVE** — already implemented (skip; add to Already Have list in the report)
- **PARTIAL** — partially implemented, gap exists (include with gap description)
- **MISSING** — not in current setup
- **CONFLICTS** — contradicts an existing rule (note conflict, do not recommend)

Compare dynamically against what was read in Step 1. Do not rely on hardcoded lists — the config changes over time and hardcoded entries go stale.

---

## Step 5 — Score Candidates

Score each `MISSING` or `PARTIAL` candidate:

```
Impact   (1–3): 1=minor convenience, 2=meaningful improvement, 3=significant capability gain
Effort   (1–3): 1=one-liner or frontmatter change, 2=new module <50 LOC, 3=new file or multi-file change
Alignment (Y/N): does it pass the philosophy gate?

Priority = Impact / Effort   (higher = better)
```

Buckets (thresholds from `config.yaml::scoring`):

- **Quick Wins:** Alignment=Y AND Priority ≥ `quick_win_threshold` (default 2.0)
- **Build Queue:** Alignment=Y AND Priority in [`build_queue_threshold`, `quick_win_threshold`)
- **Research:** items worth understanding before deciding

### Philosophy Gate

If `config.yaml::philosophy_gate` is true (default), every recommendation must pass:

> "Can I prove in one sentence that an existing primitive cannot satisfy this requirement?"

If the answer is "no" or requires more than one sentence → reject as overengineering. The single-sentence justification goes into the report's `Why` column.

This gate is the difference between a useful daily report and a noise generator. Keep it on unless you have a specific reason to disable.

---

## Step 6 — Write Report

Output file: `${config.paths.report_dir}/YYYY-MM-DD.md`

If the file already exists (same-day rerun), overwrite it.

```markdown
# Ecosystem Update — YYYY-MM-DD

## TL;DR
- {most important finding, one line}
- {second}
- {third}

## Quick Wins
| Item | Source | Type | Impact | Effort | Why | Action |
|------|--------|------|--------|--------|-----|--------|
| ... | ... | hook | 3 | 1 | one-sentence justification | Add PermissionRequest hook to settings.json |

## Build Queue
- **{Item}** ({type}) — {source} — {what it does and why it's worth building}

## Research
- [{Title}]({URL}) — {one-line relevance to current setup}

## Already Have
{comma-separated list of items previously implemented — no need to revisit}

## Rejected
- {Item} — {reason: overengineered / already covered by X / alignment failure}

## Auto-Implemented (this run)
- {Item} — {file changed} — {one-line summary}

---
_Sources checked: {URLs}_
_Tier 2 fetched: {yes/no}_
_Tier 3 fetched: {yes/no}_
_Run at: {ISO timestamp}_
```

---

## Step 7 — Save State

Update `${config.paths.state_file}` (default `~/.claude/state/ecosystem-update-last-run.json`):

```json
{
  "last_run": "{ISO timestamp}",
  "tier2_last_run": "{ISO timestamp, only update if tier 2 was fetched this run}",
  "tier3_last_run": "{ISO timestamp, only update if tier 3 was fetched this run}",
  "items_seen_count": {total count},
  "seen_items": ["{item-slug}", ...]
}
```

The `seen_items` array is the primary dedup mechanism. Each entry is the kebab-case slug of an item title. On the next run, any candidate whose slug matches an entry is bucketed as `HAVE` and skipped silently.

If a memory MCP is configured (`config.yaml::memory_mcp`), additionally save a `type: reference` observation summarizing this run's Quick Wins. This is secondary — the state file is the source of truth.

---

## Step 8 — Implement Quick Wins (default; skip if --dry-run)

Unless `--dry-run` was passed AND `config.yaml::implement_quick_wins` is true (default), implement all Quick Wins automatically.

### Before any changes — backup

```bash
mkdir -p ${config.paths.backup_dir}/YYYY-MM-DD
# Copy every file the Quick Wins target, into the dated backup directory.
```

The exact files backed up are derived from each Quick Win's Action column.

### For each Quick Win

1. Read the target file first
2. Apply the change using your editor tool of choice
3. Verify the file is syntactically valid after the edit (parse JSON / YAML / TOML; for markdown, just check it round-trips)
4. Add an entry to the report's `Auto-Implemented` section with the file path and one-line summary

### Hard limits — `config.yaml::hard_limits`

The defaults in `config.example.yaml`:

- `never_touch` — list of files the auto-implement step must never modify (default includes `~/.claude/CLAUDE.md`)
- `forbid_new_files: true` — auto-implement never creates new files; those go to the Build Queue instead
- `forbid_body_rewrites: true` — only frontmatter additions allowed; never rewrite agent or skill bodies
- `forbid_new_hooks_without_script: true` — never add a hook to settings.json that points to a script file that doesn't exist yet

These limits are enforced regardless of scoring. A Quick Win that would violate a hard limit is downgraded to Build Queue.

---

## Step 9 — Notify (optional)

If `config.yaml::notify_on_complete` is set, run the configured notification command. Defaults to no-op.

Example:
```yaml
notify_on_complete: "bash ~/.claude/bin/notify_done.sh --status success --task ecosystem-update --channel desktop"
```

---

## Scheduling

Cron at 8am:
```bash
0 8 * * * cd ~/.claude && claude --print "/ecosystem-update" >> ~/.claude/logs/ecosystem-update.log 2>&1
```

Or via the Claude Code scheduler if available:
```
/schedule daily 8am /ecosystem-update
```

---

## Source Reference (default sources.yaml example)

If you cloned the repo, `sources.example.yaml` already contains the same Claude-Code-ecosystem sources the original was built against. Copy it to `sources.yaml` and trim/extend.

For other ecosystems, see the pre-built configs in `examples/`:
- `ai-engineering.yaml`
- `security-advisories.yaml`
- `web-framework.yaml`

---

## Customization Surface — TL;DR

When you want to use this skill for a different ecosystem:

1. **Replace `sources.yaml`** — different URLs, different `extract` descriptions
2. **Override `candidate_types`** in `config.yaml` if your ecosystem has different "things you might add" (e.g. for security: `cve`, `advisory`, `mitigation`; for a web framework: `rfc`, `release`, `pattern`)
3. **Adjust hard limits** to match your codebase (e.g. `never_touch: [package.json]` if your build is fragile)
4. **Adjust scoring thresholds** to taste

You should not need to edit this `SKILL.md`. If you find yourself wanting to, that's a sign the skill needs another config knob — open an issue or PR.
