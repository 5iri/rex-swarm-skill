# rex-swarm

Run a lead agent + worker agents in [Rex](https://github.com/superlogical/rex) panes and watch their progress live, instead of burying subagents under a single summary.

```
you ── talk to ──> lead pane (any harness, with the swarm-lead skill)
                      │  swarm up / send / wait / lock          (JSON, ~100 tokens per call)
                      ▼
              .swarm/swarm.db  (SQLite: agents, messages+acks, locks, reports, events)
                ▲            ▲
   swarm ack/report/ask      swarm event  ◄── swarm-watch.lua ◄── Rex events
   (worker panes)                              (program status, exits, closes)
```

The lead only spends tokens when `swarm wait` returns an event. Workers get messages as one line typed into their pane; the full text stays in the DB. `swarm board` shows agents, locks, acked/queued messages, and reports. Each worker runs in its own visible Rex pane, so progress is never buried.

## Contents

- `bin/swarm` — stdlib-only Python 3.9+ CLI (`up`, `wait`, `send`, `ack`, `report`, `locks`, `board`, …). No daemon, no dependencies (PyYAML optional, only for `.yaml` plans).
- `rex/swarm.lua` — Rex actions + key bindings (`Swarm: open board`, `message an agent`, `correction to everyone affected`, …). Requires Rex.
- `rex/swarm-watch.lua` — Rex event forwarder started by `swarm up`, stopped by `swarm down`.
- `skills/swarm-lead/SKILL.md` — lead skill: plan, launch, `swarm wait` loop, review with evidence.
- `skills/swarm-worker/SKILL.md` — worker skill: `ack --start`, edit only owned paths, `report` with evidence.
- `examples/swarm-plan.json` — example plan with owners, interfaces, and stubs.

## Install

```sh
git clone <your-fork-url> rex-swarm
cd rex-swarm
sh install.sh
# reload Rex config (or restart Rex)
```

What it touches (re-run to update):

- `~/.local/bin/swarm`
- `~/.config/rex/swarm.lua`, `~/.config/rex/swarm-watch.lua` (adds `require("swarm")` to `init.lua`)
- `~/.claude/skills/swarm-{lead,worker}/SKILL.md`
- `~/.codex/skills/swarm-{lead,worker}/SKILL.md` (if `~/.codex` exists)

`swarm` is stdlib-only Python 3.9+. For `.yaml` plans, `pip install pyyaml`; JSON plans need nothing.

## Use

1. Open a Rex pane in your repo and start your lead: `claude`, `codex`, `opencode`, `agy`, whatever.
2. Prompt it: *"Use the swarm-lead skill. Workers: codex for X, claude (opus) for Y. Goal: ..."*
3. The lead writes `swarm-plan.json` and shows it to you. Approve it, and it runs `swarm up`, which opens one pane per worker.
4. Supervise: talk in any pane, or use the palette (`Swarm: ...` actions) or keys:
   - `ctrl+shift+b`: open the board (agents, locks, acked/queued messages, reports)
   - `ctrl+shift+n`: jump to the next agent waiting on you
   - `Swarm: correction to everyone affected`: sends your change to every owner and consumer of a path or interface, and tells the lead
   - from any shell: `swarm note "prioritise integration first"` wakes the lead

For a harness that doesn't load skills from `~/.claude/skills` or `~/.codex/skills`, add this to its `AGENTS.md` or equivalent:

```text
If you are the swarm lead/worker, read skills/swarm-lead/SKILL.md (or swarm-worker) from the rex-swarm repo and follow it.
```

Smoke test without agents: `swarm up examples/swarm-plan.json` with `"cmd": ["bash"]` on each worker. You should get labelled panes. Then try `swarm send codex hi` and `swarm board`.

## Commands

| | |
|---|---|
| lead | `up PLAN` · `wait` · `send AGENT\|all MSG` · `affected WHAT` · `lock/unlock/locks` · `status` · `log AGENT --tail N` · `focus AGENT` · `down` |
| worker | `ack --start` · `inbox [ID]` · `ack ID "restated change"` · `ask "question"` · `report --status working\|done\|blocked\|error --summary ... [--cmd --result --commit --log --release]` · `lock PATH` |
| human | `note MSG` · `send AGENT MSG` · `board` · `focus next-waiting` |
| internal | `agent-shell` (pane wrapper) · `event` (from swarm-watch.lua) · `check-commit` (git pre-commit hook) |

## Rex version notes (5 min check)

This was built against Rex's `window new` / `split` CLI and `send` + `send-key enter` for delivery:

| Thing | Check | Where to fix |
|---|---|---|
| pane creation flags | `rex window new --help`, `rex split --help` | `open_pane` in `bin/swarm` |
| message delivery (Enter) | `swarm send <agent> hi`; if it types but doesn't submit, check `rex send-key --help` | `deliver()` in `bin/swarm` |
| capture flags | `rex capture --help` | `cmd_log` in `bin/swarm` |
| focus | `rex --help` for focus / `do -e` syntax | `cmd_focus`, `cmd_agent_shell` in `bin/swarm` |
| key binding syntax | `rex help` / Rex config docs | bottom of `rex/swarm.lua` |
| agent CLI flags (`--model`, initial prompt) | `claude --help`, `codex --help`, `opencode --help`, `agy --help` | `DEFAULT_CMDS`, or `cmd` per worker in the plan |
| program status payload shape | look at `.swarm/watch.log` | `cmd_event` in `bin/swarm` |
| long `swarm wait` vs harness tool timeout | lower it with `SWARM_WAIT_TIMEOUT=110` for harnesses with a 2-min tool limit | env |

## License

MIT — see `LICENSE` (add one if missing).
