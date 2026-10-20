local M = {}

function M.run(args, cwd, ok_codes)
  local cmd = { "git", "-c", "core.quotepath=false" }
  vim.list_extend(cmd, args)
  local res = vim.system(cmd, { text = true, cwd = cwd }):wait()
  local ok = res.code == 0
  for _, code in ipairs(ok_codes or {}) do
    if res.code == code then
      ok = true
    end
  end
  if not ok then
    return nil, vim.trim(res.stderr or "")
  end
  return res.stdout
end

function M.root(cwd)
  local out, err = M.run({ "rev-parse", "--show-toplevel" }, cwd)
  if not out then
    return nil, err ~= "" and err or "not a git repository"
  end
  return vim.trim(out)
end

function M.git_dir(cwd)
  local out, err = M.run({ "rev-parse", "--absolute-git-dir" }, cwd)
  if not out then
    return nil, err
  end
  return vim.trim(out)
end

return M
