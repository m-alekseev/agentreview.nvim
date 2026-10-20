if vim.fn.has("nvim-0.10") == 0 or vim.fn.exists("*getregion") == 0 then
  vim.notify("agentreview.nvim requires nvim >= 0.10", vim.log.levels.ERROR)
  return
end

vim.api.nvim_create_user_command("AgentReview", function(o)
  require("agentreview").open(o.args)
end, { nargs = "?" })

vim.api.nvim_create_user_command("AgentReviewComment", function(o)
  require("agentreview").comment(o)
end, { range = true })

vim.api.nvim_create_user_command("AgentReviewSend", function()
  require("agentreview").send()
end, {})

vim.api.nvim_create_user_command("AgentReviewTarget", function()
  require("agentreview").target()
end, {})
