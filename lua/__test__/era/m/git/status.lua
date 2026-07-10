---@diagnostic disable: undefined-global
--- Test for era.m.git.status module
--- Run with: nvim -l lua/__test__/era/m/git/status.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.git.status")
local aggregated = nil ---@type era.m.git.status.IAggregatedCache|nil

local function normalize(filepath, keep_trailing_slash, sep)
  local had_trailing_slash = filepath:sub(-1) == "/" or filepath:sub(-1) == "\\" ---@type boolean
  local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
  if keep_trailing_slash == false and normalized ~= "/" then
    normalized = normalized:gsub("/+$", "")
  elseif keep_trailing_slash ~= false and had_trailing_slash and normalized:sub(-1) ~= "/" then
    normalized = normalized .. "/"
  end
  if sep == "\\" then
    normalized = normalized:gsub("/", "\\")
  end
  return normalized
end

bootstrap.with_runtime(t, {
  dot = {
    path = {
      normalize = normalize,
    },
  },
  era = {
    m = {
      git = {
        state = {
          aggregated = function()
            return aggregated
          end,
        },
      },
    },
  },
})

local status = require("era.m.git.status")

---@param code string
---@return era.m.git.StatusEntry
local function create_entry(code)
  local is_untracked = code == "?" ---@type boolean
  local display = is_untracked and "U" or code ---@type string
  return {
    categories = is_untracked and { untracked = true } or { modified = true, unstaged = true },
    codes = { [code] = true },
    display = display,
    path = "",
    relative = "",
    stage = is_untracked and nil or "unstaged",
    staged = {},
    staged_bits = 0,
    staged_display = "",
    summary = code,
    unstaged = { [code] = true },
    unstaged_bits = status.STATUS_CODE_BIT_MAP[code],
    unstaged_display = display,
  }
end

t:test("compute_dir_status: normalizes Windows separators for descendants", function()
  aggregated = status.aggregate({
    ["C:\\repo\\dir\\file.lua"] = create_entry("M"),
  })

  local info = status.compute_dir_status(aggregated, "C:\\repo\\dir\\")

  t.assert_true(info ~= nil, "directory info")
  t.assert_eq("M", info.display, "directory display")
end)

t:test("resolve: Windows-style descendants inherit untracked symlink status", function()
  aggregated = status.aggregate({
    ["C:\\repo\\link"] = create_entry("?"),
  })

  local display, highlight = status.resolve("C:\\repo\\link\\nested\\file.lua", "file")
  local dir_info = status.compute_dir_status(aggregated, "C:\\repo\\link\\nested\\")

  t.assert_eq("U", display, "file display")
  t.assert_eq(status.GIT_STATUS_HIGHLIGHT["?"], highlight, "file highlight")
  t.assert_true(dir_info ~= nil, "nested directory info")
  t.assert_eq("U", dir_info.display, "nested directory display")
end)

t:test("compute_dir_status: includes a directory symlink own entry", function()
  aggregated = status.aggregate({
    ["C:\\repo\\link"] = create_entry("?"),
  })

  local info = status.compute_dir_status(aggregated, "C:\\repo\\link\\")

  t.assert_true(info ~= nil, "directory info")
  t.assert_eq("U", info.display, "directory display")
end)

t:test("calc_info: mixed directory status keeps untracked U highlight", function()
  aggregated = status.aggregate({
    ["C:\\repo\\dir\\link"] = create_entry("?"),
    ["C:\\repo\\dir\\tracked.lua"] = create_entry("M"),
  })
  local highlights = {}

  local text = status.calc_info("C:\\repo\\dir\\", "directory", 0, highlights)

  t.assert_eq(" UM", text, "directory status text")
  t.assert_eq(status.GIT_STATUS_HIGHLIGHT["?"], highlights[2].hlname, "untracked character highlight")
end)

t:run()
