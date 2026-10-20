local diff = require("agentreview.diff")

local dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/fixtures/"

local function load(name)
  local lines = vim.fn.readfile(dir .. name)
  return lines, diff.parse(lines)
end

local function find(lines, text)
  for i, l in ipairs(lines) do
    if l == text then
      return i
    end
  end
  error("line not found: " .. text)
end

describe("diff.parse", function()
  local lines, parsed = load("tracked.diff")

  it("lists files with renamed and binary handled", function()
    local paths = vim.tbl_map(function(f)
      return f.path
    end, parsed.files)
    assert.same({ "bin.dat", "edit.txt", "multi.txt", "removed.txt", "renamed_new.txt" }, paths)
    assert.is_true(parsed.files[1].binary)
    assert.is_false(parsed.files[2].binary)
  end)

  it("finds every hunk", function()
    assert.equals(5, #parsed.hunks)
    assert.equals(3, parsed.hunks[3].file)
  end)

  it("maps added lines to new numbers", function()
    assert.same({ kind = "add", side = "new", num = 2 }, parsed.map[find(lines, "+TWO")])
    assert.same({ kind = "add", side = "new", num = 14 }, parsed.map[find(lines, "+FOURTEEN")])
    assert.same({ kind = "add", side = "new", num = 5 }, parsed.map[find(lines, "+added e")])
  end)

  it("maps removed lines to old numbers", function()
    assert.same({ kind = "del", side = "old", num = 2 }, parsed.map[find(lines, "-two")])
    assert.same({ kind = "del", side = "old", num = 14 }, parsed.map[find(lines, "-fourteen")])
    assert.same({ kind = "del", side = "old", num = 2 }, parsed.map[find(lines, "-gone2")])
  end)

  it("maps context lines to new numbers", function()
    assert.same({ kind = "ctx", side = "new", num = 1 }, parsed.map[find(lines, " one")])
    assert.same({ kind = "ctx", side = "new", num = 11 }, parsed.map[find(lines, " eleven")])
  end)

  it("does not map headers", function()
    assert.is_nil(parsed.map[find(lines, "rename to renamed_new.txt")])
    assert.is_nil(parsed.map[parsed.hunks[1].line])
  end)

  it("parses an untracked file diff", function()
    local ulines, uparsed = load("untracked.diff")
    assert.equals("untracked.txt", uparsed.files[1].path)
    assert.same({ kind = "add", side = "new", num = 2 }, uparsed.map[find(ulines, "+fresh2")])
  end)
end)

describe("diff.range", function()
  local lines, parsed = load("tracked.diff")

  it("returns side-aware numbers", function()
    local r = diff.range(parsed, find(lines, "-two"), find(lines, "-two"))
    assert.same({ path = "multi.txt", start = 2, ["end"] = 2 }, r)
    r = diff.range(parsed, find(lines, "-gone1"), find(lines, "-gone2"))
    assert.same({ path = "removed.txt", start = 1, ["end"] = 2 }, r)
  end)

  it("errors when crossing a file boundary", function()
    local r, err = diff.range(parsed, find(lines, "+new line"), find(lines, "-two"))
    assert.is_nil(r)
    assert.equals("selection crosses a file boundary", err)
  end)

  it("errors when no diff lines are selected", function()
    local r, err = diff.range(parsed, parsed.hunks[1].line, parsed.hunks[1].line)
    assert.is_nil(r)
    assert.equals("selection has no diff lines", err)
  end)
end)
