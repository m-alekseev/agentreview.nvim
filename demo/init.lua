local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.o.termguicolors = true
vim.o.swapfile = false
vim.o.shortmess = vim.o.shortmess .. "I"
require("agentreview").setup({ transport = "clipboard" })
vim.o.hlsearch = false
if vim.env.DEMO_EXTRA then
  dofile(vim.env.DEMO_EXTRA)
end
