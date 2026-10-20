local M = {}

local saved

function M.reset()
  saved = nil
end

local function message(err)
  if type(err) == "table" then
    return err.message or "unknown error"
  end
  return tostring(err)
end

local function choose(transport, ctx, force_picker, cb)
  local candidates, err = transport.list_targets(ctx)
  if not candidates then
    return cb(nil, message(err))
  end
  if #candidates == 0 then
    return cb(nil, "no agent in this repo")
  end
  local function done(choice)
    if not choice then
      return cb(nil, "cancelled")
    end
    local target = transport.resolve(choice.id)
    if not target then
      return cb(nil, "agent is gone")
    end
    saved = { key = transport.name .. ":" .. target.id, transport = transport.name, repo = ctx.repo_root, id = target.id }
    cb(target)
  end
  if not force_picker and (#candidates == 1 or candidates[1].preferred) then
    return done(candidates[1])
  end
  local current
  if saved and saved.transport == transport.name and saved.repo == ctx.repo_root then
    current = saved.id
  elseif candidates[1].preferred then
    current = candidates[1].id
  end
  vim.ui.select(candidates, {
    prompt = "Select agent",
    format_item = function(c)
      return c.id == current and c.label .. " (current)" or c.label
    end,
  }, done)
end

function M.get(transport, ctx, cb)
  if saved and saved.transport == transport.name and saved.repo == ctx.repo_root then
    local target = transport.resolve(saved.id)
    if target then
      saved.id = target.id
      saved.key = transport.name .. ":" .. target.id
      return cb(target)
    end
  end
  choose(transport, ctx, false, cb)
end

function M.peek(transport, ctx)
  if saved and saved.transport == transport.name and saved.repo == ctx.repo_root then
    local target = transport.resolve(saved.id)
    if target then
      return target
    end
  end
  local candidates, err = transport.list_targets(ctx)
  if not candidates then
    return nil, "error", message(err)
  end
  if #candidates == 0 then
    return nil, "none"
  end
  if #candidates == 1 or candidates[1].preferred then
    return candidates[1]
  end
  return nil, "ambiguous"
end

function M.pick(transport, ctx, cb)
  choose(transport, ctx, true, cb)
end

return M
