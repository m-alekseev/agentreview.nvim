local M = { name = "clipboard" }

local target = { id = "clipboard", label = "clipboard", status = "idle" }

function M.list_targets()
  return { target }
end

function M.resolve(id)
  if id == target.id then
    return target
  end
end

function M.send(_, text)
  local ok, err = pcall(vim.fn.setreg, "+", text)
  if not ok then
    return false, { code = "error", message = tostring(err) }
  end
  return true
end

return M
