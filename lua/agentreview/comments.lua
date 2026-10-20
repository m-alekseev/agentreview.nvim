local diff = require("agentreview.diff")

local M = { items = {} }

local ns = vim.api.nvim_create_namespace("agentreview")

vim.api.nvim_set_hl(0, "AgentReviewRange", { link = "Visual", default = true })
vim.api.nvim_set_hl(0, "AgentReviewComment", { link = "DiagnosticInfo", default = true })

local function render(c)
  local opts = { id = c.mark, hl_group = "AgentReviewRange" }
  if c.charwise then
    opts.end_row, opts.end_col = c.last - 1, c.ec
  else
    opts.end_row, opts.end_col, opts.hl_eol = c.last, 0, true
  end
  c.mark = vim.api.nvim_buf_set_extmark(M.buf, ns, c.first - 1, c.charwise and c.sc or 0, opts)

  local virt = {}
  for _, line in ipairs(vim.split(c.text, "\n", { plain = true })) do
    virt[#virt + 1] = { { "▎ " .. line, "AgentReviewComment" } }
  end
  c.vmark = vim.api.nvim_buf_set_extmark(M.buf, ns, c.first - 1, 0, { id = c.vmark, virt_lines = virt, virt_lines_above = true })
end

local function input(initial, cb)
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "wipe"
  if initial ~= "" then
    vim.api.nvim_buf_set_lines(b, 0, -1, false, vim.split(initial, "\n", { plain = true }))
  end
  local win = vim.api.nvim_open_win(b, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = 60,
    height = 5,
    style = "minimal",
    border = "rounded",
    title = " Comment ",
    title_pos = "left",
  })
  vim.wo[win].wrap = true

  local function close()
    vim.cmd.stopinsert()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  local function save()
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n"))
    close()
    if text ~= "" then
      cb(text)
    end
  end

  vim.keymap.set({ "i", "n" }, "<CR>", save, { buffer = b })
  vim.keymap.set({ "i", "n" }, "<Esc>", close, { buffer = b })
  vim.keymap.set("i", "<S-CR>", function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    vim.api.nvim_buf_set_lines(b, row - 1, row, false, { line:sub(1, col), line:sub(col + 1) })
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  end, { buffer = b })

  vim.cmd.startinsert({ bang = true })
end

function M.attach(buf, parsed)
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
  end
  M.buf, M.parsed, M.items = buf, parsed, {}
end

function M.clear()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
  end
  M.items = {}
end

function M.sorted()
  local list = vim.list_slice(M.items)
  table.sort(list, function(a, b)
    return a.first < b.first
  end)
  return list
end

function M.at(lnum)
  for _, c in ipairs(M.sorted()) do
    if c.first <= lnum and lnum <= c.last then
      return c
    end
  end
end

function M.add(sel)
  local range, err = diff.range(M.parsed, sel.first, sel.last)
  if not range then
    vim.notify("agentreview: " .. err, vim.log.levels.ERROR)
    return
  end
  local snippet = vim.api.nvim_buf_get_lines(M.buf, sel.first - 1, sel.last, false)
  input("", function(text)
    local c = {
      path = range.path,
      start = range.start,
      ["end"] = range["end"],
      snippet = snippet,
      selected = sel.charwise and sel.selected or nil,
      text = text,
      first = sel.first,
      last = sel.last,
      charwise = sel.charwise,
      sc = sel.sc,
      ec = sel.ec,
    }
    M.items[#M.items + 1] = c
    render(c)
  end)
end

function M.edit(c)
  input(c.text, function(text)
    c.text = text
    render(c)
  end)
end

function M.delete(c)
  vim.api.nvim_buf_del_extmark(M.buf, ns, c.mark)
  vim.api.nvim_buf_del_extmark(M.buf, ns, c.vmark)
  for i, item in ipairs(M.items) do
    if item == c then
      table.remove(M.items, i)
      break
    end
  end
end

function M.jump(forward)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local list = M.sorted()
  local target
  if forward then
    for _, c in ipairs(list) do
      if c.first > cur then
        target = c.first
        break
      end
    end
  else
    for i = #list, 1, -1 do
      if list[i].first < cur then
        target = list[i].first
        break
      end
    end
  end
  if target then
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

function M.list()
  local items = {}
  local sorted = M.sorted()
  for _, c in ipairs(sorted) do
    items[#items + 1] = {
      bufnr = M.buf,
      lnum = c.first,
      text = ("%s:%d-%d %s"):format(c.path, c.start, c["end"], c.text:gsub("\n", " ")),
    }
  end
  vim.fn.setqflist({}, " ", { title = "Agent review comments", items = items })
  vim.cmd.copen()
  vim.keymap.set("n", "<CR>", function()
    local c = sorted[vim.fn.line(".")]
    local win = vim.fn.bufwinid(M.buf)
    if c and win ~= -1 then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { c.first, 0 })
    end
  end, { buffer = true })
end

return M
