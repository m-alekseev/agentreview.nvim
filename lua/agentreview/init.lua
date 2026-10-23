local comments = require("agentreview.comments")
local diff = require("agentreview.diff")
local git = require("agentreview.git")
local highlight = require("agentreview.highlight")
local send = require("agentreview.send")
local target = require("agentreview.target")
local transports = require("agentreview.transport")

local M = {}

local defaults = {
  transport = "herdr",
  send_mode = "submit",
  prompt_template = "Review comments are in {path}",
  clear_on_send = true,
}

M.config = vim.deepcopy(defaults)

local function notify(msg, level)
  vim.notify("agentreview: " .. msg, level or vim.log.levels.INFO)
end

local function repo_root()
  local root, err = git.root(vim.fn.getcwd())
  if not root then
    notify(err, vim.log.levels.ERROR)
  end
  return root
end

local function get_transport()
  local t, err = transports.get(M.config.transport)
  if not t then
    notify(err, vim.log.levels.ERROR)
  end
  return t
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

local function visual_selection()
  local mode = vim.fn.mode()
  local p1, p2 = vim.fn.getpos("v"), vim.fn.getpos(".")
  if p1[2] > p2[2] or (p1[2] == p2[2] and p1[3] > p2[3]) then
    p1, p2 = p2, p1
  end
  local sel = { first = p1[2], last = p2[2] }
  if mode == "v" then
    local line = vim.fn.getline(p2[2])
    local ch = vim.fn.strcharpart(line:sub(p2[3]), 0, 1)
    sel.charwise = true
    sel.selected = table.concat(vim.fn.getregion(p1, p2, { type = "v" }), "\n")
    sel.sc = p1[3] - 1
    sel.ec = math.min(#line, p2[3] - 1 + #ch)
  end
  vim.cmd("normal! \27")
  return sel
end

local function ensure_review_buf()
  if vim.api.nvim_get_current_buf() ~= comments.buf then
    notify("not in the review buffer", vim.log.levels.ERROR)
    return false
  end
  return true
end

local function hotkey_for(command)
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    if m.rhs then
      local rhs = m.rhs:lower():gsub("^<cmd>", ""):gsub("^:", ""):gsub("<cr>$", "")
      if rhs == command:lower() then
        local lhs = m.lhs:gsub("^<Space>", " ")
        local leader = vim.g.mapleader or "\\"
        if vim.startswith(lhs, leader) then
          lhs = "<leader>" .. lhs:sub(#leader + 1)
        end
        return lhs
      end
    end
  end
end

local function show_help()
  local entries = {
    { "]h [h", "next / previous hunk" },
    { "]f [f", "next / previous file" },
    { "c", "comment (visual) / edit comment" },
    { "dc", "delete comment" },
    { "]r [r", "next / previous comment" },
    { "gl", "list comments" },
    { "g?", "this help" },
  }
  for _, g in ipairs({
    { "AgentReview", "start review" },
    { "AgentReviewCommit", "review a commit" },
    { "AgentReviewTarget", "choose target" },
    { "AgentReviewSend", "send comments" },
  }) do
    local key = hotkey_for(g[1])
    if key then
      entries[#entries + 1] = { key, g[2] }
    end
  end

  local key_width, width = 0, 0
  for _, e in ipairs(entries) do
    key_width = math.max(key_width, vim.fn.strdisplaywidth(e[1]))
  end
  local lines = {}
  for _, e in ipairs(entries) do
    local line = " " .. e[1] .. string.rep(" ", key_width - vim.fn.strdisplaywidth(e[1])) .. "  " .. e[2] .. " "
    lines[#lines + 1] = line
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - #lines) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " Agent review ",
    title_pos = "center",
  })
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, lhs in ipairs({ "q", "<Esc>", "<CR>", "g?" }) do
    vim.keymap.set("n", lhs, close, { buffer = buf, nowait = true })
  end
  vim.api.nvim_create_autocmd("BufLeave", { buffer = buf, once = true, callback = close })
end

local function set_keymaps(buf)
  local function map(mode, lhs, fn)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, silent = true })
  end
  map("n", "]h", function()
    diff.next_hunk(comments.parsed, true)
  end)
  map("n", "[h", function()
    diff.next_hunk(comments.parsed, false)
  end)
  map("n", "]f", function()
    diff.next_file(comments.parsed, true)
  end)
  map("n", "[f", function()
    diff.next_file(comments.parsed, false)
  end)
  map("x", "c", function()
    comments.add(visual_selection())
  end)
  map("n", "c", function()
    local c = comments.at(vim.api.nvim_win_get_cursor(0)[1])
    if c then
      comments.edit(c)
    end
  end)
  map("n", "dc", function()
    local c = comments.at(vim.api.nvim_win_get_cursor(0)[1])
    if c then
      comments.delete(c)
    end
  end)
  map("n", "]r", function()
    comments.jump(true)
  end)
  map("n", "[r", function()
    comments.jump(false)
  end)
  map("n", "gl", comments.list)
  map("n", "g?", show_help)
end

local function refresh_winbar()
  if not (comments.buf and vim.api.nvim_buf_is_valid(comments.buf)) then
    return
  end
  local win = vim.fn.bufwinid(comments.buf)
  local transport = transports.get(M.config.transport)
  if win == -1 or not transport or not M.root then
    return
  end
  local t, reason = target.peek(transport, { repo_root = M.root })
  local text
  if t then
    text = "→ " .. t.label
  elseif reason == "none" then
    text = "→ no agent running"
  elseif reason == "ambiguous" then
    local hotkey = hotkey_for("AgentReviewTarget")
    text = "→ no agent here · " .. (hotkey and ("press " .. hotkey) or "run :AgentReviewTarget") .. " to choose"
  else
    text = "→ agent lookup failed"
  end
  vim.wo[win].winbar = (text:gsub("%%", "%%%%"))
end

local function show(root, lines, parsed, scope)
  if #comments.items > 0 then
    notify(("discarding %d comment(s) from the previous review"):format(#comments.items), vim.log.levels.WARN)
  end
  if comments.buf and vim.api.nvim_buf_is_valid(comments.buf) then
    vim.api.nvim_buf_delete(comments.buf, { force = true })
  end

  local cur = vim.api.nvim_get_current_buf()
  local empty = vim.api.nvim_buf_get_name(cur) == ""
    and not vim.bo[cur].modified
    and vim.api.nvim_buf_line_count(cur) == 1
    and vim.api.nvim_buf_get_lines(cur, 0, 1, false)[1] == ""
  local buf
  if empty then
    buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_delete(cur, { force = true })
  else
    vim.cmd("tabnew")
    buf = vim.api.nvim_get_current_buf()
  end
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "diff"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_set_name(buf, "agentreview://diff")
  vim.wo.number = true
  vim.wo.signcolumn = "yes:1"
  vim.wo.statuscolumn = "%=%l%s"
  vim.wo.conceallevel = 2
  vim.wo.concealcursor = "nvic"
  highlight.apply(buf, lines, parsed)

  M.root = root
  M.scope = scope
  comments.attach(buf, parsed)
  set_keymaps(buf)
  refresh_winbar()
end

function M.open(base)
  local root = repo_root()
  if not root then
    return
  end
  local lines, parsed = diff.build(base ~= "" and base or nil, root)
  if not lines then
    notify(parsed, vim.log.levels.ERROR)
    return
  end
  local scope = "changes not committed yet (staged, unstaged and untracked files)"
  if base ~= "" then
    scope = ("all changes since %s, committed and not (tracked files only)"):format(base)
  end
  show(root, lines, parsed, scope)
end

local function open_rev(root, rev)
  local lines, parsed = diff.build(nil, root, rev)
  if not lines then
    notify(parsed, vim.log.levels.ERROR)
    return
  end
  local out, err = git.run({ "show", "-s", "--format=%H %s", rev }, root)
  if not out then
    notify(err, vim.log.levels.ERROR)
    return
  end
  show(root, lines, parsed, "commit " .. vim.trim(out))
end

function M.open_commit(rev)
  local root = repo_root()
  if not root then
    return
  end
  if rev ~= "" then
    return open_rev(root, rev)
  end
  local list, err = diff.commits(root)
  if not list then
    notify(err, vim.log.levels.ERROR)
    return
  end
  if #list == 0 then
    notify("no commits", vim.log.levels.ERROR)
    return
  end
  vim.ui.select(list, {
    prompt = "Select commit",
    format_item = function(c)
      return c.label
    end,
  }, function(choice)
    if choice then
      open_rev(root, choice.rev)
    end
  end)
end

function M.comment(o)
  if not ensure_review_buf() then
    return
  end
  if o.range == 0 then
    notify("select a block first", vim.log.levels.ERROR)
    return
  end
  comments.add({ first = o.line1, last = o.line2 })
end

function M.send()
  if #comments.items == 0 then
    notify("no comments to send", vim.log.levels.ERROR)
    return
  end
  local transport = get_transport()
  local root = M.root or repo_root()
  if not transport or not root then
    return
  end
  send.send({
    comments = comments.sorted(),
    scope = M.scope,
    transport = transport,
    repo_root = root,
    template = M.config.prompt_template,
  }, function(ok, err)
    if not ok then
      notify(err, vim.log.levels.ERROR)
      return
    end
    if M.config.clear_on_send then
      comments.clear()
    end
    refresh_winbar()
  end)
end

function M.target()
  local transport = get_transport()
  local root = M.root or repo_root()
  if not transport or not root then
    return
  end
  target.pick(transport, { repo_root = root }, function(t, err)
    if not t then
      notify(err, vim.log.levels.ERROR)
      return
    end
    refresh_winbar()
  end)
end

return M
