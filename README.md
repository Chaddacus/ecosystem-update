# ecosystem-update

A Claude Code skill that runs daily, scans the sources you care about for new patterns, diffs them against your current setup, implements the quick wins, and writes a dated report.

Originally built to keep my personal Claude Code config current with the broader community ecosystem. Now generic — point it at any set of URLs and it'll do the same job.

## What it does

1. **Reads your current state** — config files, installed agents, skills, MCP servers (paths configurable)
2. **Fetches sources** — URLs from `sources.yaml`, organized into tiers (daily / weekly / monthly)
3. **Extracts candidates** — discrete items it found that you might want to add
4. **Diffs against current state** — buckets each candidate as `HAVE`, `PARTIAL`, `MISSING`, or `CONFLICTS`
5. **Scores remaining items** — Impact / Effort / Alignment-with-philosophy
6. **Writes a dated markdown report** to `~/.claude/reports/ecosystem/YYYY-MM-DD.md`
7. **Implements quick wins automatically** — high-impact, low-effort, philosophy-aligned changes (with backups + hard limits, configurable)
8. **Saves dedup state** so it never reports the same item twice

The dedup state is the key thing — it's why running this daily doesn't drown you in noise.

## Why you'd use it

You're building something on top of a fast-moving ecosystem (Claude Code, agentic frameworks, web frameworks, ML tooling, security advisories — anything where the community ships new patterns weekly). You want to stay current without spending an hour every day reading.

Cron this once. Read a 2-minute report each morning. The skill does the rest.

## Install

```bash
git clone https://github.com/Chaddacus/ecosystem-update ~/.claude/skills/ecosystem-update
cd ~/.claude/skills/ecosystem-update
cp sources.example.yaml sources.yaml
cp config.example.yaml config.yaml
# edit sources.yaml — add the URLs you want to track
# edit config.yaml — adjust paths if your Claude home isn't ~/.claude
```

Then in Claude Code:

```
/ecosystem-update
```

For a dry run (report only, no auto-implement):

```
/ecosystem-update --dry-run
```

## Customize

### `sources.yaml`

The URLs you want scanned, organized into tiers. Tiers control how often each source is fetched:

```yaml
tier_1_daily:
  - url: https://github.com/some-org/awesome-thing
    extract: "new patterns, new modules added to the catalog"
  - url: https://creatorblog.example.com/
    extract: "creator's latest tips and patterns"

tier_2_daily_optional:  # skipped if last_run < 24h ago
  - url: https://arxiv.org/search/?query=relevant+topic&order=-announced_date_first
    extract: "papers from the last 24h with applicable patterns"

tier_3_weekly:           # skipped if last_run < 7d ago
  - url: https://some-comprehensive-catalog.example/
    extract: "comprehensive catalog updates"
```

Pre-built example configs in [`examples/`](examples/):
- [`ai-engineering.yaml`](examples/ai-engineering.yaml) — Claude Code, MCP, agent patterns, AI eng research
- [`security-advisories.yaml`](examples/security-advisories.yaml) — CVEs, security blogs, advisories
- [`web-framework.yaml`](examples/web-framework.yaml) — frontend framework releases, RFC discussions

Copy any of these to `sources.yaml` to get started.

### `config.yaml`

Paths, scoring weights, and hard limits:

```yaml
paths:
  state_file: ~/.claude/state/ecosystem-update-last-run.json
  report_dir: ~/.claude/reports/ecosystem/
  backup_dir: ~/.claude/backups/

scoring:
  quick_win_threshold: 2.0   # Priority = Impact / Effort
  build_queue_threshold: 1.0

implement_quick_wins: true   # set false for report-only behavior

hard_limits:
  never_touch:
    - ~/.claude/CLAUDE.md     # constitutional policy doc — never auto-edit
  forbid_new_files: true      # auto-implement never creates new files
  forbid_body_rewrites: true  # only frontmatter additions to existing files

philosophy_gate: true         # require one-sentence justification per recommendation
```

### Philosophy gate

Every recommendation has to pass a one-sentence test:

> "Can I prove in one sentence that an existing primitive cannot satisfy this requirement?"

If the answer is "no" or needs more than one sentence — rejected as overengineering. This is how the skill stays useful instead of recommending shiny things you'd never need. Disable in `config.yaml` if you want — but it's the heart of why this tool doesn't waste your time.

## How the dedup actually works

After every run, `state_file` (default `~/.claude/state/ecosystem-update-last-run.json`) gets a `seen_items` array of slugified item titles. On the next run, candidates whose slug matches the list are silently bucketed as `HAVE` and skipped.

This is what makes daily runs sustainable — without it, you'd see the same items every time the catalog source updated.

## Schedule it

Cron at 8am daily:

```bash
0 8 * * * cd ~/.claude && claude --print "/ecosystem-update" >> ~/.claude/logs/ecosystem-update.log 2>&1
```

Or use the Claude Code scheduler if you have one wired:

```
/schedule daily 8am /ecosystem-update
```

The skill is headless-safe: no interactive prompts, deterministic exit, idempotent on same-day reruns.

## What I run it on

I built this for my personal Claude Code config. It's been running daily for 47+ consecutive days as of writing, zero misses. Every morning I get a 1-page markdown report at `~/.claude/reports/ecosystem/YYYY-MM-DD.md` with quick wins already applied to my config and a build queue of bigger items I might pick up.

That's why this is generic now — the loop works, the philosophy gate keeps the noise down, and there's no reason it should only watch Claude Code sources.

## License

MIT.

## Credit

Concept and original implementation by [Chad Simon](https://github.com/Chaddacus). Open source so you can adapt it to whatever ecosystem you live in.
