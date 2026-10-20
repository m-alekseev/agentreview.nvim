local M = { name = "herdr" }

local terminals = {}

local function run(args)
  local cmd = { "herdr" }
  vim.list_extend(cmd, args)
  local ok, proc = pcall(vim.system, cmd, { text = true })
  if not ok then
    return nil, { code = "error", message = tostring(proc) }
  end
  local res = proc:wait()
  local decoded_ok, decoded = pcall(vim.json.decode, res.stdout or "")
  if not decoded_ok or type(decoded) ~= "table" then
    return nil, { code = "error", message = vim.trim(res.stderr or "") ~= "" and vim.trim(res.stderr) or "invalid herdr output" }
  end
  if decoded.error then
    return nil, { code = decoded.error.code or "error", message = decoded.error.message or "herdr error" }
  end
  return decoded.result
end

local function status_of(agent)
  local s = agent.agent_status
  if s == "done" then
    return "idle"
  end
  if s == "idle" or s == "working" or s == "blocked" then
    return s
  end
  return "unknown"
end

local function label_of(agent)
  local kind = agent.agent or "agent"
  local title = agent.name or agent.terminal_title_stripped
  if not title or title == "" then
    title = agent.display_agent or kind
  elseif kind ~= "claude" then
    title = kind .. " " .. title
  end
  local cwd = agent.cwd and vim.fn.fnamemodify(agent.cwd, ":~") or ""
  return ("%s · %s [%s] %s"):format(cwd, title, status_of(agent), agent.pane_id)
end

local function to_target(agent)
  terminals[agent.pane_id] = agent.terminal_id
  return {
    id = agent.pane_id,
    label = label_of(agent),
    status = status_of(agent),
  }
end

local function inside(path, root)
  return type(path) == "string" and (path == root or vim.startswith(path, root .. "/"))
end

function M.list_targets(ctx)
  local result, err = run({ "agent", "list" })
  if not result then
    return nil, err
  end
  local near, far = {}, {}
  for _, agent in ipairs(result.agents or {}) do
    local t = to_target(agent)
    if inside(agent.cwd, ctx.repo_root) or inside(agent.foreground_cwd, ctx.repo_root) then
      t.preferred = true
      near[#near + 1] = t
    else
      far[#far + 1] = t
    end
  end
  return vim.list_extend(near, far)
end

function M.resolve(id)
  local result = run({ "agent", "get", id })
  if result and result.agent then
    return to_target(result.agent)
  end
  local terminal_id = terminals[id]
  if not terminal_id then
    return nil
  end
  local listed = run({ "agent", "list" })
  for _, agent in ipairs(listed and listed.agents or {}) do
    if agent.terminal_id == terminal_id then
      return to_target(agent)
    end
  end
end

function M.send(target, text)
  local args
  if require("agentreview").config.send_mode == "paste" then
    args = { "pane", "send-text", target.id, text }
  else
    args = { "agent", "prompt", target.id, text }
  end
  local result, err = run(args)
  if not result then
    if err.code == "agent_blocked" then
      err.code = "blocked"
    end
    return false, err
  end
  return true
end

return M
