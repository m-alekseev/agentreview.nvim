local M = {}

function M.validate(t)
  if type(t) ~= "table" then
    return nil, "transport must be a table"
  end
  if type(t.name) ~= "string" or t.name == "" then
    return nil, "transport.name must be a non-empty string"
  end
  for _, fn in ipairs({ "list_targets", "resolve", "send" }) do
    if type(t[fn]) ~= "function" then
      return nil, ("transport %s: %s must be a function"):format(t.name, fn)
    end
  end
  return t
end

function M.get(spec)
  if type(spec) == "string" then
    local ok, t = pcall(require, "agentreview.transport." .. spec)
    if not ok then
      return nil, ("unknown transport: %s"):format(spec)
    end
    return M.validate(t)
  end
  return M.validate(spec)
end

return M
