local M = {}

local ns = vim.api.nvim_create_namespace("agentreview_hl")

vim.api.nvim_set_hl(0, "AgentReviewAdd", { link = "Added", default = true })
vim.api.nvim_set_hl(0, "AgentReviewDel", { link = "Removed", default = true })

vim.api.nvim_set_hl(0, "AgentReviewAddWord", { link = "DiffAdd", default = true })
vim.api.nvim_set_hl(0, "AgentReviewDelWord", { link = "DiffDelete", default = true })

local diff_fn = vim.text and vim.text.diff or vim.diff

local function tokens(s)
  local out, pos = {}, 1
  while pos <= #s do
    local t = s:match("^[%w_\128-\255]+", pos) or s:match("^%s+", pos) or s:sub(pos, pos)
    out[#out + 1] = { text = t, from = pos - 1, to = pos - 1 + #t }
    pos = pos + #t
  end
  return out
end

local function joined(toks)
  local parts = {}
  for i, t in ipairs(toks) do
    parts[i] = t.text
  end
  return table.concat(parts, "\n") .. "\n"
end

local function ranges(toks, changed)
  local out, cur = {}, nil
  for i, t in ipairs(toks) do
    if changed[i] then
      if cur then
        cur[2] = t.to
      else
        cur = { t.from, t.to }
        out[#out + 1] = cur
      end
    else
      cur = nil
    end
  end
  return out
end

function M.word_ranges(old, new)
  local ta, tb = tokens(old), tokens(new)
  local changed_a, changed_b = {}, {}
  for _, h in ipairs(diff_fn(joined(ta), joined(tb), { result_type = "indices" })) do
    for i = h[1], h[1] + h[2] - 1 do
      changed_a[i] = true
    end
    for i = h[3], h[3] + h[4] - 1 do
      changed_b[i] = true
    end
  end
  local function size(toks)
    local n = 0
    for _, t in ipairs(toks) do
      if not t.text:match("^%s+$") then
        n = n + #t.text
      end
    end
    return n
  end
  local kept = 0
  for i, t in ipairs(ta) do
    if not changed_a[i] and not t.text:match("^%s+$") then
      kept = kept + #t.text
    end
  end
  local total = math.max(size(ta), size(tb))
  return ranges(ta, changed_a), ranges(tb, changed_b), total == 0 and 0 or kept / total
end

local function mark(buf, lnum, col, opts)
  vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, col, opts)
end

local function chrome(buf, lines, parsed)
  for lnum, _ in ipairs(lines) do
    local m = parsed.map[lnum]
    if m then
      local opts = { end_col = 1, conceal = "" }
      if m.kind ~= "ctx" then
        opts.sign_text = " ▎"
        opts.sign_hl_group = m.kind == "add" and "AgentReviewAdd" or "AgentReviewDel"
      end
      mark(buf, lnum, 0, opts)
    elseif not m and parsed.file_of[lnum] then
      local group = "Comment"
      if lines[lnum]:match("^diff %-%-git ") then
        group = "Title"
      elseif lines[lnum]:match("^@@ ") then
        group = "Special"
      end
      mark(buf, lnum, 0, { end_row = lnum - 1, end_col = #lines[lnum], hl_group = group })
    end
  end
end

local function code_side(buf, lines, parsed, hunk, last, lang, query, side)
  local src, rows = {}, {}
  for lnum = hunk.line + 1, last do
    local m = parsed.map[lnum]
    if m and (m.kind == "ctx" or m.kind == (side == "new" and "add" or "del")) then
      src[#src + 1] = lines[lnum]:sub(2)
      rows[#rows + 1] = lnum
    end
  end
  if #src == 0 then
    return
  end
  local text = table.concat(src, "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, lang)
  if not ok then
    return
  end
  local tree = parser:parse()[1]
  if not tree then
    return
  end
  for id, node in query:iter_captures(tree:root(), text) do
    local name = query.captures[id]
    if name:sub(1, 1) ~= "_" then
      local sr, sc, er, ec = node:range()
      for r = sr, er do
        local lnum = rows[r + 1]
        local m = lnum and parsed.map[lnum]
        if m and (side == "new" or m.kind == "del") then
          local from = r == sr and sc or 0
          local to = r == er and ec or #src[r + 1]
          if to > from then
            mark(buf, lnum, from + 1, {
              end_col = to + 1,
              hl_group = "@" .. name .. "." .. lang,
              priority = 110,
            })
          end
        end
      end
    end
  end
end

local function syntax(buf, lines, parsed)
  local hunks_by_file = {}
  for _, hunk in ipairs(parsed.hunks) do
    hunks_by_file[hunk.file] = hunks_by_file[hunk.file] or {}
    table.insert(hunks_by_file[hunk.file], hunk)
  end
  for fi, file in ipairs(parsed.files) do
    local ft = vim.filetype.match({ filename = file.path })
    local lang = ft and vim.treesitter.language.get_lang(ft)
    local query = lang and lang ~= "diff" and vim.treesitter.query.get(lang, "highlights")
    if query then
      local hunks = hunks_by_file[fi] or {}
      for i, hunk in ipairs(hunks) do
        local last = (hunks[i + 1] and hunks[i + 1].line or (parsed.files[fi + 1] and parsed.files[fi + 1].line or #lines + 1)) - 1
        code_side(buf, lines, parsed, hunk, last, lang, query, "new")
        code_side(buf, lines, parsed, hunk, last, lang, query, "old")
      end
    end
  end
end

local function pair(buf, lines, del, add)
  local old, new = lines[del]:sub(2), lines[add]:sub(2)
  if #old > 2000 or #new > 2000 then
    return
  end
  local old_ranges, new_ranges, similarity = M.word_ranges(old, new)
  if similarity < 0.5 then
    return
  end
  for _, r in ipairs(old_ranges) do
    mark(buf, del, r[1] + 1, { end_col = r[2] + 1, hl_group = "AgentReviewDelWord", priority = 120 })
  end
  for _, r in ipairs(new_ranges) do
    mark(buf, add, r[1] + 1, { end_col = r[2] + 1, hl_group = "AgentReviewAddWord", priority = 120 })
  end
end

local function words(buf, lines, parsed)
  local lnum = 1
  while lnum <= #lines do
    local m = parsed.map[lnum]
    if m and m.kind == "del" then
      local dels, adds = {}, {}
      while parsed.map[lnum] and parsed.map[lnum].kind == "del" do
        dels[#dels + 1] = lnum
        lnum = lnum + 1
      end
      while parsed.map[lnum] and parsed.map[lnum].kind == "add" do
        adds[#adds + 1] = lnum
        lnum = lnum + 1
      end
      for i = 1, math.min(#dels, #adds) do
        pair(buf, lines, dels[i], adds[i])
      end
    else
      lnum = lnum + 1
    end
  end
end

function M.apply(buf, lines, parsed)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.treesitter.stop(buf)
  vim.bo[buf].syntax = "OFF"
  chrome(buf, lines, parsed)
  syntax(buf, lines, parsed)
  words(buf, lines, parsed)
end

return M
