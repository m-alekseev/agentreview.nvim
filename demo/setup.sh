set -e
dir=/tmp/agentreview-demo
rm -rf "$dir"
mkdir -p "$dir"
cd "$dir"
git init -q -b master
git config user.email demo@example.com
git config user.name demo

cat > app.lua <<'LUA'
local http = require("http")
local log = require("log")

local M = {}

local retries = 3

function M.fetch(url)
  local res = http.get(url)
  return res.body
end

function M.parse(body)
  return vim.json.decode(body)
end

function M.validate(data)
  return type(data) == "table"
end

function M.name()
  return "demo"
end

-- legacy retry count
function M.run(job)
  log.info("starting " .. job.name)
  return M.fetch(job.url)
end

return M
LUA
git add app.lua
git commit -q -m "add app"

cat > util.lua <<'LUA'
local M = {}

function M.clamp(n, lo, hi)
  return math.max(lo, math.min(n, hi))
end

return M
LUA
git add util.lua
git commit -q -m "add util"

cat > app.lua <<'LUA'
local http = require("http")
local log = require("log")

local M = {}

local retries = 5

function M.fetch(url)
  local res = http.get(url, { timeout = 10 })
  return res.body
end

function M.parse(body)
  return vim.json.decode(body)
end

function M.validate(data)
  return type(data) == "table"
end

function M.name()
  return "demo"
end

function M.run(job)
  log.info("starting job " .. job.name)
  log.debug("retries: " .. retries)
  return M.fetch(job.url)
end

return M
LUA

cat > config.lua <<'LUA'
return {
  retries = 5,
  timeout = 10,
}
LUA
