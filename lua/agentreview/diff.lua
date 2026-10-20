local git = require("agentreview.git")

local M = {}

function M.parse(lines)
  local files, hunks, map, file_of = {}, {}, {}, {}
  local file, in_hunk, old_n, new_n

  for lnum, line in ipairs(lines) do
    local gb = line:match("^diff %-%-git a/.* b/(.*)$")
    if gb then
      file = { path = gb, line = lnum, binary = false }
      files[#files + 1] = file
      in_hunk = false
    elseif file and not in_hunk and line:match("^rename to ") then
      file.path = line:sub(11)
    elseif file and not in_hunk and line:match("^%+%+%+ b/") then
      file.path = vim.trim(line:sub(7))
    elseif file and not in_hunk and line:match("^Binary files ") then
      file.binary = true
    elseif file and line:match("^@@ ") then
      local a, c = line:match("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
      if a then
        old_n, new_n, in_hunk = tonumber(a), tonumber(c), true
        hunks[#hunks + 1] = { line = lnum, file = #files }
      end
    elseif in_hunk then
      local ch = line:sub(1, 1)
      if ch == "+" then
        map[lnum] = { kind = "add", side = "new", num = new_n }
        new_n = new_n + 1
      elseif ch == "-" then
        map[lnum] = { kind = "del", side = "old", num = old_n }
        old_n = old_n + 1
      elseif ch == " " or line == "" then
        map[lnum] = { kind = "ctx", side = "new", num = new_n }
        old_n, new_n = old_n + 1, new_n + 1
      end
    end
    if file then
      file_of[lnum] = #files
    end
  end

  return { files = files, hunks = hunks, map = map, file_of = file_of }
end

function M.range(parsed, s, e)
  local first = parsed.file_of[s]
  if not first then
    return nil, "selection is outside the diff"
  end
  local start_num, end_num
  for l = s, e do
    if parsed.file_of[l] ~= first then
      return nil, "selection crosses a file boundary"
    end
    local m = parsed.map[l]
    if m then
      start_num = start_num or m.num
      end_num = m.num
    end
  end
  if not start_num then
    return nil, "selection has no diff lines"
  end
  return { path = parsed.files[first].path, start = start_num, ["end"] = end_num }
end

local function default_base(root)
  if git.run({ "rev-parse", "--verify", "-q", "HEAD" }, root) then
    return "HEAD"
  end
  local tree = git.run({ "hash-object", "-t", "tree", "/dev/null" }, root)
  return tree and vim.trim(tree) or "HEAD"
end

local function collect(base, root)
  local args = { "diff", "--no-color", "--no-ext-diff", base or default_base(root), "--" }
  local out, err = git.run(args, root)
  if not out then
    return nil, err
  end
  local chunks = { out }
  if not base then
    local untracked = git.run({ "ls-files", "--others", "--exclude-standard" }, root)
    for path in vim.gsplit(untracked or "", "\n", { plain = true, trimempty = true }) do
      local d = git.run({ "diff", "--no-color", "--no-index", "--", "/dev/null", path }, root, { 1 })
      chunks[#chunks + 1] = d
    end
  end
  return table.concat(chunks)
end

function M.build(base, root)
  local text, err = collect(base, root)
  if not text then
    return nil, err
  end
  local lines = vim.split(text, "\n", { plain = true })
  if lines[#lines] == "" then
    lines[#lines] = nil
  end
  if #lines == 0 then
    return nil, "no changes"
  end
  return lines, M.parse(lines)
end

local function jump(list, forward, key)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if forward then
    for _, item in ipairs(list) do
      if item[key] > cur then
        target = item[key]
        break
      end
    end
  else
    for i = #list, 1, -1 do
      if list[i][key] < cur then
        target = list[i][key]
        break
      end
    end
  end
  if target then
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

function M.next_hunk(parsed, forward)
  jump(parsed.hunks, forward, "line")
end

function M.next_file(parsed, forward)
  jump(parsed.files, forward, "line")
end

return M
