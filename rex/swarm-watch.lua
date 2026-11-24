-- swarm-watch.lua: forwards Rex events to `swarm event`. Started by `swarm up` as
--   rex do ~/.config/rex/swarm-watch.lua --all
-- and stopped by `swarm down`. Runs until killed.
--
-- Only these events are forwarded; everything else stays out of swarm (and out of any
-- agent's context). swarm itself ignores blocks that aren't registered agents.


local function forward(name, ctx, ev)
  local payload = {
    name     = name,
    block_id = ev.block_id or ctx.block_id,
    exit_code = ev.exit_code,
    id       = ev.id,
    record   = ev.record,
    reason   = ev.reason,
  }
  local text, err = rex.json.encode(payload)
  if not text then rex.log("warn", "swarm-watch encode: " .. tostring(err)); return end
  local r = rex.exec({ "/bin/sh", "-lc", 'exec swarm event -', "swarm" }, { stdin = text, timeout = 10 })
  if r == nil or not r.ok then
    rex.log("warn", "swarm-watch: swarm event failed: " .. tostring(r and r.stderr or ""))
  end
end

rex.on("terminal.program_status_changed", function(ctx, ev) forward("program_status_changed", ctx, ev) end)
rex.on("terminal.child_exited",           function(ctx, ev) forward("child_exited", ctx, ev) end)
rex.on("block_closed",                    function(ctx, ev) forward("block_closed", ctx, ev) end)

rex.log("info", "swarm-watch: forwarding program status, exits and closes")
