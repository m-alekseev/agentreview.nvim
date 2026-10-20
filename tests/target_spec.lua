local target = require("agentreview.target")

local ctx = { repo_root = "/repo" }

local function fake(candidates)
  local t = { name = "fake", gone = {} }
  t.list_targets = function()
    return candidates
  end
  t.resolve = function(id)
    if t.gone[id] then
      return nil
    end
    for _, c in ipairs(candidates) do
      if c.id == id then
        return c
      end
    end
  end
  return t
end

local a = { id = "a", label = "claude a", status = "idle" }
local b = { id = "b", label = "claude b", status = "working" }

describe("target", function()
  local select_calls, select_index, orig

  before_each(function()
    target.reset()
    select_calls, select_index = 0, 2
    orig = vim.ui.select
    vim.ui.select = function(items, _, cb)
      select_calls = select_calls + 1
      cb(items[select_index])
    end
  end)

  after_each(function()
    vim.ui.select = orig
  end)

  it("errors with no candidates", function()
    local res, err
    target.get(fake({}), ctx, function(t, e)
      res, err = t, e
    end)
    assert.is_nil(res)
    assert.equals("no agent in this repo", err)
  end)

  it("picks a single candidate without prompting", function()
    local res
    target.get(fake({ a }), ctx, function(t)
      res = t
    end)
    assert.equals("a", res.id)
    assert.equals(0, select_calls)
  end)

  it("prompts with several candidates and remembers the choice", function()
    local tr = fake({ a, b })
    local res
    target.get(tr, ctx, function(t)
      res = t
    end)
    assert.equals("b", res.id)
    assert.equals(1, select_calls)
    target.get(tr, ctx, function(t)
      res = t
    end)
    assert.equals("b", res.id)
    assert.equals(1, select_calls)
  end)

  it("re-prompts when the saved target is gone", function()
    local tr = fake({ a, b })
    target.get(tr, ctx, function() end)
    tr.gone.b = true
    select_index = 1
    local res
    target.get(tr, ctx, function(t)
      res = t
    end)
    assert.equals("a", res.id)
    assert.equals(2, select_calls)
  end)

  it("takes the first preferred candidate without prompting", function()
    local res
    target.get(fake({ { id = "a", label = "a", status = "idle", preferred = true }, b }), ctx, function(t)
      res = t
    end)
    assert.equals("a", res.id)
    assert.equals(0, select_calls)
  end)

  it("pick prompts even when a candidate is preferred", function()
    local res
    select_index = 2
    target.pick(fake({ { id = "a", label = "a", status = "idle", preferred = true }, b }), ctx, function(t)
      res = t
    end)
    assert.equals("b", res.id)
    assert.equals(1, select_calls)
  end)

  it("marks the saved target in the picker", function()
    local labels
    vim.ui.select = function(items, opts, cb)
      labels = vim.tbl_map(opts.format_item, items)
      cb(items[2])
    end
    local tr = fake({ a, b })
    target.get(tr, ctx, function() end)
    assert.same({ "claude a", "claude b" }, labels)
    target.pick(tr, ctx, function() end)
    assert.same({ "claude a", "claude b (current)" }, labels)
  end)

  it("marks the default target in the picker before any choice", function()
    local labels
    vim.ui.select = function(items, opts, cb)
      labels = vim.tbl_map(opts.format_item, items)
      cb(items[1])
    end
    target.pick(fake({ { id = "a", label = "claude a", status = "idle", preferred = true }, b }), ctx, function() end)
    assert.same({ "claude a (current)", "claude b" }, labels)
  end)

  it("peek returns the default without saving or prompting", function()
    local t = target.peek(fake({ { id = "a", label = "a", status = "idle", preferred = true }, b }), ctx)
    assert.equals("a", t.id)
    assert.equals(0, select_calls)
  end)

  it("peek returns the saved target", function()
    local tr = fake({ a, b })
    target.get(tr, ctx, function() end)
    assert.equals("b", target.peek(tr, ctx).id)
  end)

  it("peek reports none and ambiguous", function()
    local t, reason = target.peek(fake({}), ctx)
    assert.is_nil(t)
    assert.equals("none", reason)
    t, reason = target.peek(fake({ a, b }), ctx)
    assert.is_nil(t)
    assert.equals("ambiguous", reason)
  end)

  it("pick always prompts", function()
    local res
    select_index = 1
    target.pick(fake({ a }), ctx, function(t)
      res = t
    end)
    assert.equals(1, select_calls)
    assert.equals("a", res.id)
  end)

  it("does not reuse a saved target from another repo", function()
    local tr = fake({ a, b })
    target.get(tr, ctx, function() end)
    target.get(tr, { repo_root = "/other" }, function() end)
    assert.equals(2, select_calls)
  end)
end)
