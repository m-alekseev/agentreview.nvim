local export = require("agentreview.export")
local git = require("agentreview.git")
local target = require("agentreview.target")

local M = {}

function M.send(opts, done)
  local git_dir, err = git.git_dir(opts.repo_root)
  if not git_dir then
    return done(false, err)
  end
  local path = git_dir .. "/agent-review.md"
  if vim.fn.writefile(vim.split(export.render(opts.comments), "\n", { plain = true }), path) ~= 0 then
    return done(false, "cannot write " .. path)
  end
  local prompt = opts.template:gsub("{path}", function()
    return path
  end)

  target.get(opts.transport, { repo_root = opts.repo_root }, function(t, terr)
    if not t then
      return done(false, terr)
    end
    local ok, serr = opts.transport.send(t, prompt)
    if ok then
      return done(true)
    end
    if type(serr) == "table" and serr.code == "blocked" then
      return done(false, "agent is blocked; comments kept", "blocked")
    end
    done(false, type(serr) == "table" and serr.message or tostring(serr))
  end)
end

return M
