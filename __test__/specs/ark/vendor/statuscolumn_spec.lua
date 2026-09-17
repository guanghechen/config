---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ark.vendor.statuscolumn" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("ark.vendor.statuscolumn")
local expression = "%!v:lua.era.dressing.statuscolumn.statuscolumn()"

---@return integer
local function create_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
end

---@param bufnr                         integer
---@param config                        vim.api.keyset.win_config
---@return integer
local function create_win(bufnr, config)
  local winnr = vim.api.nvim_open_win(bufnr, true, config)
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  return winnr
end

for _, vendor in ipairs({ "neovim", "neovide" }) do
  t:test(vendor .. " initializes the gutter before plugins create splits and focus a picker", function()
    local dressing = assert(loadfile("lua/era/dressing/init.lua"))()
    local Statuscolumn = assert(loadfile("lua/era/dressing/statuscolumn.lua"))()
    t:patch_table(package.loaded, "era.dressing.statuscolumn", Statuscolumn)
    for name in pairs(dressing.__mods) do
      if name ~= "statuscolumn" then
        dressing[name] = { dressing = function() end }
      end
    end
    local modules = {}
    for _, name in ipairs({ "input", "lsp", "select", "image", "paste", "splitjoin", "surrounds", "textobject" }) do
      modules[name] = { dressing = function() end, setup = function() end }
    end
    local completed = false
    bootstrap.with_runtime(t, {
      era = { dressing = dressing, m = modules },
      dot = {
        setup_context = function() end,
        setup_diagnostics = function() end,
        path = {
          is_git_repo = function()
            return false
          end,
        },
        context = {
          watch_changes = function()
            completed = true
          end,
        },
      },
    })

    local source_bufnr = create_buf()
    local picker_bufnr = create_buf()
    local file_bufnr = create_buf()
    vim.api.nvim_buf_set_lines(file_bufnr, 0, -1, false, { "local value = 1" })
    local source_winnr = create_win(source_bufnr, { split = "right" })
    vim.api.nvim_set_option_value("statuscolumn", "", {})
    local split_winnr, picker_winnr
    local original_require = require
    t:patch_global("require", function(name)
      if name == "era.plugin" then
        split_winnr = create_win(source_bufnr, { split = "below" })
        picker_winnr = create_win(picker_bufnr, {
          relative = "editor",
          row = 0,
          col = 0,
          width = 20,
          height = 3,
          style = "minimal",
        })
        return {}
      end
      if name:match("^ark%.vendor%.") or name == "dot.autocmd" or name == "era.command" then
        return {}
      end
      return original_require(name)
    end)

    assert(loadfile("lua/ark/vendor/" .. vendor .. "/init.lua"))()
    t.wait_until(function()
      return completed
    end, 1000, "deferred vendor setup did not complete")

    local picker_expression = vim.api.nvim_get_option_value("statuscolumn", { win = picker_winnr })
    vim.api.nvim_set_current_win(source_winnr)
    vim.api.nvim_win_close(picker_winnr, true)
    vim.api.nvim_win_set_buf(source_winnr, file_bufnr)

    t.assert_eq(expression, vim.api.nvim_get_option_value("statuscolumn", { win = source_winnr }))
    t.assert_eq(expression, vim.api.nvim_get_option_value("statuscolumn", { scope = "global" }))
    t.assert_eq(expression, vim.api.nvim_get_option_value("statuscolumn", { win = split_winnr }))
    t.assert_eq("", picker_expression, "minimal picker keeps its local override")
  end)
end

t:run()
