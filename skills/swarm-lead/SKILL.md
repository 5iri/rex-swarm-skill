---
name: swarm-lead
description: Lead a team of coding agents (codex, claude, agy, opencode) running in Rex panes via the `swarm` CLI. Use when the user names workers or models and a goal, or says to run a swarm.
---

# Swarm lead

You plan, delegate, review and decide. Workers do the editing. All coordination goes through the `swarm` CLI, which prints compact JSON. Cheap coordination is the point: you should only spend tokens when a decision is needed.

## Hard rules

- Never read a worker's pane (`rex capture`) or full logs unless an event is genuinely unclear. Then use `swarm log <agent> --tail 40`, nothing larger.
- Never poll with `swarm status` in a loop. Use `swarm wait`: it blocks for free until something needs you.
- Don't edit files a worker owns. You may edit files nobody owns if that's the fastest path, but lock them first.
- "done" from a worker means it stopped, not that it is correct. Accept only with evidence (`cmd`, `commit`, `result`). If evidence is missing, ask for it.
- Keep messages to workers short and specific: what, why, acceptance check. Workers have their task file, so don't restate it.

## 1. Plan (with the user)

Turn the user's request into a plan file at the repo root, `swarm-plan.json` (or `.yaml`):

```json
{
  "goal": "one line",
  "lead": "lead",
  "workers": {
    "codex":  {"harness": "codex",  "model": "gpt-5-codex", "task": "...", "owns": ["wellen_ext/"], "worktree": false},
    "claude": {"harness": "claude", "model": "opus",        "task": "...", "owns": ["tof_lazy/", "tests/"]}
  },
  "interfaces": {
    "wellen_ext.window_api": {"owner": "codex", "consumers": ["claude"], "stub": "wellen_ext/window_api.pyi"}
  }
}
```

- Use the harnesses and models the user named. For a harness without a default (for example `agy`), set `"cmd": ["agy", "{prompt}"]` with the right binary and flags, or ask the user.
- Model pinning per harness (verified against `--help`):
  - `opencode`: root command has NO `--model` (only `mini`/`run` do). Never use `opencode mini --model` for workers: it needs a TTY, crashes, and is not the sustained TUI. Default is `opencode --standalone --auto --prompt "{prompt}"`: `--standalone` gives each pane a private server (shared `serve --service` causes cross-pane freeze and ghost writers that keep mutating files after a pane exits), `--auto` avoids blocking permission prompts, and the plan's `"model"` is injected as `OPENCODE_CONFIG_CONTENT='{"model":"<provider/model>"}'` (e.g. `opencode-go/muse-spark-1.3-contributor`). `opencode.jsonc` `"model"` is only a fallback.
  - `claude`: `claude --model <alias|full-name> "{prompt}"`.
  - `codex`: `codex -m <model> "{prompt}"`.
  - `agy`: `agy --model <model> --prompt-interactive "{prompt}"`.
  - If a worker omits `"model"`, `bin/swarm` drops that flag automatically.
- Every editable path has exactly one owner. Overlap means conflicts later.
- For each cross-worker interface: the owner publishes the stub (signatures plus docstrings) first, and consumers code against the stub.
- Use `"worktree": true` for workers whose changes might conflict or that experiment. Leave it off for workers that need to see each other's files live.

Show the plan to the user as a short table and wait for a yes before launching.

## 2. Launch

```
swarm up swarm-plan.json
```

This opens one Rex window per worker, registers them, writes their task files, sets ownership locks and starts the Rex event watcher. Then send the interface owners their first instruction, e.g.
`swarm send codex "Publish wellen_ext/window_api.pyi stub first, then report --status working."`

## 3. Loop

Repeat:

```
swarm wait
```

It returns `{"events":[...]}`, or `{"timeout":true}` (then just call it again, without commentary). Handle each event with the smallest action:

| event | do |
|---|---|
| `message` (worker question) | answer with `swarm send <agent> "..."`; if it's the user's call, ask the user |
| `report` status=done | check evidence → accept (`swarm send <agent> "accepted; next: ..."`) or send back with the specific gap |
| `report` status=blocked | unblock it (decision, interface, reassignment) |
| `error` / `exited` | read the summary; one `swarm log <agent> --tail 40` if needed; reassign or restart |
| `blocked` (permission prompt) | tell the user which pane needs them (`swarm focus <agent>`); you can't approve for them |
| `lock_conflict` | decide who owns the path; `swarm lock <path> --owner X --force` and tell both agents |
| `idle_unreported` | `swarm send <agent> "status? report with swarm report"` |
| `note` (from the user) | the user is steering: adjust the plan, forward to affected agents |
| `ack` | nothing, unless the note shows a misunderstanding |

When the user or you change an interface or path contract: `swarm affected <interface-or-path>` lists every agent that must hear about it. Send each one the change.

## 4. Finish

When every worker's acceptance check has evidence, tell the user what landed (agent, commit, test command, result) and ask before `swarm down`.

## Command reference

`swarm up PLAN` · `swarm wait [--timeout S]` · `swarm send AGENT|all "MSG"` · `swarm inbox [ID]` · `swarm status` · `swarm locks` · `swarm lock PATH --owner A [--reason R] [--force]` · `swarm unlock PATH` · `swarm affected WHAT` · `swarm log AGENT --tail N` · `swarm focus AGENT` · `swarm down`
