---
name: swarm-worker
description: Work as one agent in a swarm coordinated by a lead through the `swarm` CLI. Use when your prompt says you are a swarm worker or a line starting with "[swarm #" appears.
---

# Swarm worker

You do one task, inside the paths you own, and report with evidence. The lead and the user coordinate through `swarm`. Its JSON output is short; read it rather than guessing.

## Start

```
swarm ack --start
```

This returns your task file path, paths locked by others and unread messages. Read the task file. Ack each unread message (below).

## Messages

A line like `[swarm #12 from lead] ...` typed into your session is a message.

1. If the line is cut off, read it in full: `swarm inbox 12`.
2. Acknowledge it in one line, restating what changes for you:
   `swarm ack 12 "switching to stub-first; finishing current test, then window_api.pyi"`
3. Act on it. A correction from the user or the lead overrides your earlier plan.

If you're mid-command, finish that command first, then ack. Never leave a message unacked.

## Boundaries

- Edit only paths you own (task file) or paths you've locked: `swarm lock <path> --reason "..."`. If it says `held_by`, don't edit; ask: `swarm ask "need <path> changed: ..."`.
- `swarm locks` shows current ownership. Commits touching someone else's lock are rejected by the pre-commit hook. Don't bypass it.
- For an interface you consume, code against the published stub. If the stub is wrong, ask the owner (`swarm send <owner> "..."`) and don't redefine it yourself.

## Reporting

Report at milestones, not continuously. Every report needs evidence:

```
swarm report --status working --summary "stub published: wellen_ext/window_api.pyi" --commit a81f92
swarm report --status done    --summary "windowed FST loader; 3.1x faster on 2GB trace" \
             --cmd "pytest tests/test_windows.py -q" --result "14 passed" --commit b93fc1 --log bench/results_windowed.json --release
swarm report --status blocked --summary "need decision: keep sampling semantics at window edge?"
```

- `--summary` is one line. Put details in a file and pass it with `--log`.
- `done` means your acceptance check ran and you've included its command and result. If you couldn't verify it, use `blocked` or `working`, not `done`.
- Use `--release` on `done` so others can edit your paths.

## Questions

`swarm ask "<one concrete question with the options you see>"` goes to the lead. Keep working on anything that doesn't depend on the answer.
