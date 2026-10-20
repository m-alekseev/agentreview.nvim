local export = require("agentreview.export")

describe("export.render", function()
  it("renders a linewise comment", function()
    local out = export.render({
      { path = "a.lua", start = 3, ["end"] = 4, snippet = { "-old", "+new" }, text = "why?" },
    })
    assert.equals("# Code review comments\n\n## a.lua:3-4\n```diff\n-old\n+new\n```\nwhy?\n", out)
  end)

  it("adds selected text for characterwise comments", function()
    local out = export.render({
      { path = "a.lua", start = 1, ["end"] = 1, snippet = { "+foo bar" }, selected = "bar", text = "rename" },
    })
    assert.is_truthy(out:find("Selected text: ` bar `\nrename\n", 1, true))
  end)

  it("uses a longer fence when the snippet contains backticks", function()
    local out = export.render({
      { path = "a.md", start = 1, ["end"] = 1, snippet = { "+```" }, text = "x" },
    })
    assert.is_truthy(out:find("````diff\n+```\n````\n", 1, true))
  end)
end)
