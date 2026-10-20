local transport = require("agentreview.transport")

local function fake()
  return {
    name = "fake",
    list_targets = function() end,
    resolve = function() end,
    send = function() end,
  }
end

describe("transport", function()
  it("accepts a valid table", function()
    assert.is_table(transport.get(fake()))
  end)

  it("rejects a missing name", function()
    local t = fake()
    t.name = nil
    assert.is_nil(transport.get(t))
  end)

  it("rejects a missing function", function()
    local t = fake()
    t.send = nil
    local res, err = transport.get(t)
    assert.is_nil(res)
    assert.is_truthy(err:find("send"))
  end)

  it("loads built-in transports by name", function()
    assert.equals("clipboard", transport.get("clipboard").name)
    assert.equals("herdr", transport.get("herdr").name)
  end)

  it("rejects an unknown name", function()
    assert.is_nil(transport.get("nope"))
  end)
end)
