local M = {}

local function fence(text)
  local longest = 0
  for run in text:gmatch("`+") do
    longest = math.max(longest, #run)
  end
  return string.rep("`", math.max(3, longest + 1))
end

local function inline(text)
  local longest = 0
  for run in text:gmatch("`+") do
    longest = math.max(longest, #run)
  end
  local ticks = string.rep("`", longest + 1)
  return ticks .. " " .. text .. " " .. ticks
end

function M.render(comments, scope)
  local out = { "# Code review comments" }
  if scope then
    out[#out + 1] = ""
    out[#out + 1] = "Reviewing: " .. scope
  end
  for _, c in ipairs(comments) do
    local snippet = table.concat(c.snippet, "\n")
    local f = fence(snippet)
    out[#out + 1] = ""
    out[#out + 1] = ("## %s:%d-%d"):format(c.path, c.start, c["end"])
    out[#out + 1] = f .. "diff"
    out[#out + 1] = snippet
    out[#out + 1] = f
    if c.selected then
      if c.selected:find("\n", 1, true) then
        local sf = fence(c.selected)
        out[#out + 1] = "Selected text:"
        out[#out + 1] = sf
        out[#out + 1] = c.selected
        out[#out + 1] = sf
      else
        out[#out + 1] = "Selected text: " .. inline(c.selected)
      end
    end
    out[#out + 1] = c.text
  end
  return table.concat(out, "\n") .. "\n"
end

return M
