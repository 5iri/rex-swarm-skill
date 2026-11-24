-- swarm.lua: Rex config module. In ~/.config/rex/init.lua add:   require("swarm")
--
-- Config-time Lua can register actions and key bindings (not event handlers; those
-- live in swarm-watch.lua, which `swarm up` starts with `rex do ... --all`).
-- Every action is a thin wrapper over the `swarm` CLI, so the same verbs work from
-- the palette, from keys, from `rex do swarm_send ...`, and from agents' shells.

local M = {}

-- Login shell so ~/.local/bin (or wherever you put `swarm`) is on PATH.
local function swarm(args)
  local argv = { "/bin/sh", "-lc", 'exec swarm "$@"', "swarm" }
  for _, a in ipairs(args) do argv[#argv + 1] = tostring(a) end
  local r, err = rex.exec(argv, { timeout = 30 })
  if r == nil then
    rex.log("error", "swarm: " .. tostring(err))
    return nil, err
  end
  if not r.ok then
    rex.log("warn", "swarm " .. table.concat(args, " ") .. ": " .. (r.stderr or ""))
  end
  return r.stdout, r
end

-- Open a command in a new window (tab).
local function open_window(cmd)
  rex.session.new_window{
    layout = rex.layout.block{
      flavor  = "com.superlogical.terminal.shell",
      options = { command = { "/bin/sh", "-lc", cmd } },
    },
  }
end

rex.action{
  name = "swarm_board", title = "Swarm: open board", category = "Swarm",
  description = "Live view of agents, locks, messages and reports",
  run = function(ctx, args) open_window("swarm board") end,
}

rex.action{
  name = "swarm_send", title = "Swarm: message an agent", category = "Swarm",
  args = { to = "string", body = "string" },
  run = function(ctx, args) return swarm({ "send", args.to, args.body }) end,
}

rex.action{
  name = "swarm_note", title = "Swarm: note to lead", category = "Swarm",
  description = "Wakes the lead's `swarm wait` with your note",
  args = { body = "string" },
  run = function(ctx, args) return swarm({ "note", args.body }) end,
}

rex.action{
  name = "swarm_correct", title = "Swarm: correction to everyone affected", category = "Swarm",
  description = "Sends the correction to every agent that owns or consumes the path/interface",
  args = { what = "string", body = "string" },
  run = function(ctx, args)
    local outp = swarm({ "affected", args.what })
    local list = outp and rex.json.decode(outp) or {}
    for _, name in ipairs(list) do
      swarm({ "send", name, "[correction re " .. args.what .. "] " .. args.body })
    end
    swarm({ "note", "user sent correction re " .. args.what .. " to " .. table.concat(list, ",") .. ": " .. args.body })
    return list
  end,
}

rex.action{
  name = "swarm_lock", title = "Swarm: lock a path", category = "Swarm",
  args = { path = "string", owner = "string", reason = "string?" },
  run = function(ctx, args)
    return swarm({ "lock", args.path, "--owner", args.owner, "--reason", args.reason or "user lock" })
  end,
}

rex.action{
  name = "swarm_unlock", title = "Swarm: unlock a path", category = "Swarm",
  args = { path = "string" },
  run = function(ctx, args) return swarm({ "unlock", args.path }) end,
}

rex.action{
  name = "swarm_next_waiting", title = "Swarm: jump to next agent waiting on you", category = "Swarm",
  run = function(ctx, args) return swarm({ "focus", "next-waiting" }) end,
}

rex.action{
  name = "swarm_focus", title = "Swarm: focus an agent", category = "Swarm",
  args = { agent = "string" },
  run = function(ctx, args) return swarm({ "focus", args.agent }) end,
}

-- Key bindings. Change to taste; check for clashes with `rex.bindings()`.
rex.bind("ctrl+shift+b", "swarm_board")
rex.bind("ctrl+shift+n", "swarm_next_waiting")

return M
