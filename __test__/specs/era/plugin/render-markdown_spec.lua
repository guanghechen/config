local harness = require("__test__.support.harness")
local Grid = require("__test__.support.ui_grid")
local UI = require("__test__.support.ui")
local t = harness.new()

local ROOT = assert(vim.uv.cwd()) ---@type string
local PLUGIN = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "render-markdown.nvim") ---@type string
-- The last cell of each row of a rendered table: its right border.
local BORDERS = { ["│"] = true, ["╮"] = true, ["┤"] = true, ["╯"] = true } ---@type table<string, true>

---Starts the full configuration in a UI child, with this checkout as its config directory and its cache in a temporary
---one.
---@return __test__.support.UI
---@return table grid
local function start()
  local dir = t:tempdir()
  local appname = vim.env.NVIM_APPNAME or "nvim" ---@type string
  assert(vim.uv.fs_symlink(ROOT, vim.fs.joinpath(dir, appname), { junction = true }))
  -- The child inherits the environment it starts with.
  local config, cache = vim.env.XDG_CONFIG_HOME, vim.env.XDG_CACHE_HOME
  vim.env.XDG_CONFIG_HOME, vim.env.XDG_CACHE_HOME = dir, vim.fs.joinpath(dir, "cache")
  local ui = UI.open(t, nil, { init = vim.fs.joinpath(dir, appname, "init.lua"), cwd = dir, timeout_ms = 30000 })
  vim.env.XDG_CONFIG_HOME, vim.env.XDG_CACHE_HOME = config, cache
  local grid = Grid.new(ui)
  ui:rpc("nvim_ui_attach", 60, 16, { rgb = true, ext_linegrid = true })
  return ui, grid
end

---The screen column of the right border of every table row on screen, and whether a color swatch shows.
---@param grid                          table
---@param markers                       string[] Text that only the table's rows show.
---@return integer[]
---@return boolean
local function table_layout(grid, markers)
  local borders, swatch = {}, false ---@type integer[], boolean
  for _, screen in pairs(grid.grids) do
    for _, cells in ipairs(screen.rows) do
      local text = table.concat(vim.tbl_map(function(cell)
        return cell[1]
      end, cells))
      local in_table = vim.iter(markers):any(function(marker)
        return text:find(marker, 1, true) ~= nil
      end)
      if in_table then
        local last = nil ---@type integer|nil
        for col, cell in ipairs(cells) do
          swatch = swatch or cell[1] == "󱓻"
          last = BORDERS[cell[1]] and col or last
        end
        borders[#borders + 1] = last or 0
      end
    end
  end
  return borders, swatch
end

t:test("a color swatch in a table cell keeps the table's columns aligned", function()
  if not vim.uv.fs_stat(PLUGIN) then
    t.skip("render-markdown.nvim is not installed")
  end
  local path = vim.fs.joinpath(t:tempdir(), "colors.md")
  vim.fn.writefile(
    { "# Colors", "", "| name | color   |", "| ---- | ------- |", "| a    | #ff8800 |", "| bb   | plain   |" },
    path
  )
  local ui, grid = start()
  ui:wait_lua("return vim.v.vim_did_enter == 1", 20000, "configuration started")
  ui:lua("vim.cmd.edit(...)", path)
  ui:wait_lua("return package.loaded['render-markdown'] ~= nil", 20000, "render-markdown loaded")
  ui:lua("require('era.dressing.hipattern').enable(0); require('render-markdown').render({ buf = 0 })")
  local markers = { "╭", "├", "╰", "name", "plain", "ff8800" }
  local borders, swatch = {}, false ---@type integer[], boolean
  local ok = pcall(ui.wait_until, ui, function()
    borders, swatch = table_layout(grid, markers)
    return swatch and #borders == 6 and vim.iter(borders):all(function(col)
      return col == borders[1]
    end)
  end, 10000, "an aligned table with a swatch on screen")
  t.assert_true(ok, "right borders " .. vim.inspect(borders) .. (swatch and "" or ", no swatch on screen"))
end)

t:run()
