--- Run with: nvim -l lua/__test__/era/dressing/hipattern/buffer.lua

local harness = require("__test__.harness")

local t = harness.new("era.dressing.hipattern.buffer")
local Hipattern = require("era.dressing.hipattern")
local Filetype = require("stl.filetype")

Hipattern.dressing()

---@param bufnr                         integer
---@return table[]
local function get_extmarks(bufnr)
  return vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })
end

---@param bufnr                         integer
---@param count                         integer
---@return nil
local function wait_for_extmarks(bufnr, count)
  t.wait_until(function()
    return #get_extmarks(bufnr) == count
  end, 1000, string.format("expected %d extmarks", count))
end

---@param lines                         string[]
---@param filetype                      string
---@param callback                      fun(bufnr: integer): nil
---@return nil
local function with_buffer(lines, filetype, callback)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })

  local ok, err = pcall(callback, bufnr)
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end

t:test("renders keyword and inline color decorations", function()
  with_buffer({ "TODO #ff0000" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 2)

    local keyword = nil ---@type table|nil
    local color = nil ---@type table|nil
    for _, extmark in ipairs(get_extmarks(bufnr)) do
      local details = extmark[4]
      if details.hl_group == "f_hipattern_todo" then
        keyword = extmark
      elseif details.virt_text ~= nil then
        color = extmark
      end
    end
    t.assert_true(keyword ~= nil, "keyword extmark")
    t.assert_eq(4, keyword and keyword[4].end_col, "keyword end")
    t.assert_true(color ~= nil, "color extmark")
    t.assert_eq("EraHipatternColor_ff0000", color and color[4].virt_text[1][2], "color group")
  end)
end)

t:test("replaces repeated same-line updates without stale extmarks", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "DONE" })
    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 1 and extmarks[1][4].hl_group == "f_hipattern_success"
    end, 1000, "success highlight")

    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "plain" })
    wait_for_extmarks(bufnr, 0)
  end)
end)

t:test("keeps extmarks aligned across line insertion and deletion", function()
  with_buffer({ "TODO", "plain", "ERROR" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 2)

    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "head" })
    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 2 and extmarks[1][2] == 1 and extmarks[2][2] == 3
    end, 1000, "inserted line positions")

    vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})
    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 1 and extmarks[1][2] == 2 and extmarks[1][4].hl_group == "f_hipattern_error"
    end, 1000, "deleted line positions")
  end)
end)

t:test("structural edits invalidate pending ranges in current coordinates", function()
  local lines = {} ---@type string[]
  for index = 1, 130 do
    lines[index] = "plain"
  end
  lines[101] = "TODO"

  with_buffer(lines, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_buf_set_lines(bufnr, 100, 101, false, { "DONE" })
    local inserted = {} ---@type string[]
    for index = 1, 20 do
      inserted[index] = "head"
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, inserted)

    t.wait_until(function()
      local extmarks = get_extmarks(bufnr)
      return #extmarks == 1 and extmarks[1][2] == 120 and extmarks[1][4].hl_group == "f_hipattern_success"
    end, 1000, "shifted pending range")
  end)
end)

t:test("disjoint edits preserve extmarks between dirty ranges", function()
  local lines = {} ---@type string[]
  for index = 1, 100 do
    lines[index] = "plain"
  end
  lines[50] = "NOTE"

  with_buffer(lines, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)
    local middle_id = get_extmarks(bufnr)[1][1] ---@type integer

    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "TODO" })
    vim.api.nvim_buf_set_lines(bufnr, 99, 100, false, { "ERROR" })
    wait_for_extmarks(bufnr, 3)

    local preserved = false ---@type boolean
    for _, extmark in ipairs(get_extmarks(bufnr)) do
      if extmark[1] == middle_id and extmark[2] == 49 and extmark[4].hl_group == "f_hipattern_info" then
        preserved = true
      end
    end
    t.assert_true(preserved, "middle extmark identity")
  end)
end)

t:test("tail deletion clears sentinel extmarks", function()
  with_buffer({ "plain", "TODO", "ERROR" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 2)

    vim.api.nvim_buf_set_lines(bufnr, 1, 3, false, {})
    wait_for_extmarks(bufnr, 0)
  end)
end)

t:test("uses the target buffer filetype during background updates", function()
  with_buffer({ "rgb(255, 0, 0)" }, "css", function(bufnr)
    vim.api.nvim_set_option_value("filetype", "lua", { buf = 0 })
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)
    t.assert_eq("EraHipatternColor_ff0000", get_extmarks(bufnr)[1][4].virt_text[1][2], "background color")
  end)
end)

t:test("toggle clears and restores buffer decorations", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)
    t.assert_true(Hipattern.is_enabled(bufnr), "enabled")

    Hipattern.toggle(bufnr)
    t.assert_false(Hipattern.is_enabled(bufnr), "disabled")
    t.assert_eq(0, #get_extmarks(bufnr), "cleared")

    Hipattern.toggle(bufnr)
    t.assert_true(Hipattern.is_enabled(bufnr), "re-enabled")
    wait_for_extmarks(bufnr, 1)
  end)
end)

t:test("eligibility is owned by hipattern", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    for _, value in ipairs({ "", Filetype.BIGFILE, Filetype.BOARD, "diff", "excalidraw", "git-credentials" }) do
      vim.api.nvim_set_option_value("filetype", value, { buf = bufnr })
      Hipattern.enable(bufnr)
      t.assert_false(Hipattern.is_enabled(bufnr), value == "" and "empty filetype" or value)
      t.assert_eq(0, #get_extmarks(bufnr), "disabled decorations")
    end

    vim.api.nvim_set_option_value("filetype", "unknown-filetype", { buf = bufnr })
    Hipattern.enable(bufnr)
    t.assert_true(Hipattern.is_enabled(bufnr), "unknown filetype")
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_set_option_value("buftype", "prompt", { buf = bufnr })
    Hipattern.enable(bufnr)
    t.assert_false(Hipattern.is_enabled(bufnr), "prompt buffer")
    t.assert_eq(0, #get_extmarks(bufnr), "prompt decorations")
  end)
end)

t:test("filetype changes reconcile eligibility", function()
  with_buffer({ "TODO" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_set_option_value("filetype", "board", { buf = bufnr })
    t.assert_false(Hipattern.is_enabled(bufnr), "disabled after filetype change")
    t.assert_eq(0, #get_extmarks(bufnr), "cleared after filetype change")

    vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
    t.assert_true(Hipattern.is_enabled(bufnr), "enabled after filetype change")
    wait_for_extmarks(bufnr, 1)
  end)
end)

t:test("eligible nofile buffers are enabled by filetype", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "TODO", "---Title---" })
  vim.api.nvim_set_option_value("filetype", "notepad", { buf = bufnr })

  local ok, err = pcall(function()
    t.assert_true(Hipattern.is_enabled(bufnr), "notepad enabled")
    wait_for_extmarks(bufnr, 2)
  end)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)

t:test("colorscheme restores generated color groups", function()
  with_buffer({ "#ff0000" }, "lua", function(bufnr)
    Hipattern.enable(bufnr)
    wait_for_extmarks(bufnr, 1)

    vim.api.nvim_set_hl(0, "EraHipatternColor_ff0000", {})
    t.assert_eq(nil, vim.api.nvim_get_hl(0, { name = "EraHipatternColor_ff0000" }).fg, "cleared color")
    vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
    t.assert_true(vim.api.nvim_get_hl(0, { name = "EraHipatternColor_ff0000" }).fg ~= nil, "restored color")
  end)
end)

t:run()
