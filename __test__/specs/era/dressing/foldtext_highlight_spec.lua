---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.dressing.foldtext_highlight" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("era.dressing.foldtext highlights")

t:test("fold badge stays opaque over inactive window blending across themes", function()
  t:patch_global("yoz", require("yoz"))
  t:patch_global("stl", require("stl"))
  t:patch_global("dot", require("dot"))
  t:patch_global("__test_foldtext", require("era.dressing.foldtext").foldtext)
  t:patch_table(vim.treesitter, "get_captures_at_pos", function()
    return {}
  end)

  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local lines = { "size = 16" }
  for _ = 1, 20 do
    lines[#lines + 1] = "folded line"
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local winnrs = {}
  for _, split in ipairs({ "right", "below" }) do
    local winnr = vim.api.nvim_open_win(bufnr, true, { split = split })
    winnrs[#winnrs + 1] = winnr
    t:defer(function()
      vim.api.nvim_win_close(winnr, true)
    end)
    for name, value in pairs({
      number = false,
      relativenumber = false,
      signcolumn = "no",
      foldcolumn = "0",
      cursorline = false,
      wrap = false,
      foldmethod = "manual",
      foldtext = "v:lua.__test_foldtext()",
      winhighlight = "Normal:m_dv_normal",
    }) do
      vim.api.nvim_set_option_value(name, value, { win = winnr })
    end
    vim.cmd("1,$fold")
  end
  vim.api.nvim_set_current_win(winnrs[1])

  -- The first inspection enables hlstate; redraw afterward to refresh attribute IDs.
  vim.api.nvim__redraw({ valid = false, flush = true })
  vim.api.nvim__inspect_cell(1, 0, 0)

  ---@param winnr                       integer
  ---@param col                         integer
  ---@return table
  local function cell(winnr, col)
    local pos = vim.api.nvim_win_get_position(winnr)
    return vim.api.nvim__inspect_cell(1, pos[1], pos[2] + col)
  end

  local cap_col = vim.api.nvim_strwidth(lines[1]) + 2
  local text_col = cap_col + vim.api.nvim_strwidth(stl.icon.symbols.sep_left)
  local end_col = text_col + vim.api.nvim_strwidth("↙ 20 lines")
  for _, theme in ipairs(dot.var.themes) do
    for _, transparency in ipairs({ false, true }) do
      dot.context.theme.apply_theme({ theme = theme, transparency = transparency })
      vim.api.nvim__redraw({ valid = false, flush = true })

      for index, winnr in ipairs(winnrs) do
        local context = string.format("%s transparency=%s window=%d", theme, transparency, index)
        local middle = cell(winnr, text_col)
        t.assert_eq("↙", middle[1], context .. ": fold badge is rendered")
        t.assert_eq(0, middle[2].blend or 0, context .. ": badge background remains opaque")
        t.assert_eq(cell(winnr, cap_col)[2].foreground, middle[2].background, context .. ": left cap matches")
        t.assert_eq(cell(winnr, end_col)[2].foreground, middle[2].background, context .. ": right cap matches")
      end

      local gap = cell(winnrs[2], cap_col - 1)
      t.assert_eq(transparency and 50 or 0, gap[2].blend or 0, "inactive window blending remains unchanged")
    end
  end
end)

t:run()
