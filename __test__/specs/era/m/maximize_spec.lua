--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/maximize_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.maximize")
local enums = assert(loadfile("lua/stl/e.lua"))()
local maximized = assert(loadfile("lua/dot/state/maximized.lua"))()

local winnr_command = 0 ---@type integer
local warnings = {} ---@type table[]
local forked_winnrs = nil ---@type integer[]|nil

bootstrap.with_runtime(t, {
  dot = {
    context = {
      theme = {
        get_float_winblend = function()
          return 0
        end,
      },
    },
    state = {
      maximized = maximized,
      status = {
        dirtier_tabline = { mark_dirty = function() end },
        get_winnr_command = function()
          return winnr_command
        end,
      },
    },
    tab = {
      add_buf = function() end,
      resolve = function() end,
    },
    win = {
      fork = function(source_winnr, target_winnr)
        forked_winnrs = { source_winnr, target_winnr }
      end,
    },
  },
  stl = {
    box = require("stl.box"),
    e = enums,
    nvim = {
      fn = {
        is_statusline_visible = function()
          return false
        end,
        is_tabline_visible = function()
          return false
        end,
      },
      win = {
        is_float = function(winnr)
          return vim.api.nvim_win_get_config(winnr).relative ~= ""
        end,
      },
    },
    reporter = {
      warn = function(report)
        warnings[#warnings + 1] = report
      end,
    },
  },
})

local Maximize = assert(loadfile("lua/era/m/maximize.lua"))()

---@param tabnr                         integer
---@return nil
local function close_tab(tabnr)
  if not vim.api.nvim_tabpage_is_valid(tabnr) or #vim.api.nvim_list_tabpages() <= 1 then
    return
  end
  local tabid = vim.api.nvim_tabpage_get_number(tabnr) ---@type integer
  pcall(vim.api.nvim_cmd, { cmd = "tabclose", args = { tostring(tabid) } }, {})
end

---@param tabnr                         integer
---@param winnr                         integer
---@param bufnr                         integer
---@param created_bufnrs                integer[]
---@param extra_tabnrs                  ?integer[]
---@return nil
local function register_cleanup(tabnr, winnr, bufnr, created_bufnrs, extra_tabnrs)
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    local normal = maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
    if normal ~= nil then
      normal.closing = true
      close_tab(normal.maximize_tabnr)
      pcall(vim.api.nvim_del_augroup_by_id, normal.augroup)
      maximized.clear_normal()
    end

    if vim.api.nvim_tabpage_is_valid(tabnr) then
      vim.api.nvim_set_current_tabpage(tabnr)
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_set_current_win(winnr)
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_win_set_buf(winnr, bufnr)
        end
      end
    end

    for _, extra_tabnr in ipairs(extra_tabnrs or {}) do
      close_tab(extra_tabnr)
    end
    for _, created_bufnr in ipairs(created_bufnrs) do
      if vim.api.nvim_buf_is_valid(created_bufnr) then
        pcall(vim.api.nvim_buf_delete, created_bufnr, { force = true })
      end
    end
    winnr_command = 0
    forked_winnrs = nil
    warnings = {}
  end)
end

t:test("normal maximize uses a transient tab and syncs final buffer view", function()
  local source_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(source_winnr) ---@type integer
  local source_bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  local final_bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  register_cleanup(source_tabnr, source_winnr, original_bufnr, { source_bufnr, final_bufnr })

  vim.api.nvim_buf_set_lines(source_bufnr, 0, -1, false, { "one", "two", "three" })
  vim.api.nvim_buf_set_lines(final_bufnr, 0, -1, false, { "1", "2", "3", "4", "5", "6" })
  vim.api.nvim_win_set_buf(source_winnr, source_bufnr)
  vim.api.nvim_win_set_cursor(source_winnr, { 2, 0 })
  t.assert_false(vim.t[source_tabnr].tabtype == enums.TabTypeEnum.MAXIMIZE, "initial source tabtype")

  winnr_command = source_winnr
  Maximize.toggle()

  local normal = maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
  t.assert_true(normal ~= nil, "normal context")
  ---@cast normal dot.state.maximized.INormalContext
  t.assert_true(normal.maximize_tabnr ~= source_tabnr, "separate maximize tab")
  t.assert_eq(enums.TabTypeEnum.MAXIMIZE, vim.t[normal.maximize_tabnr].tabtype, "maximize tabtype")
  t.assert_eq(1, #vim.api.nvim_tabpage_list_wins(normal.maximize_tabnr), "maximize window count")
  t.assert_eq(source_bufnr, vim.api.nvim_win_get_buf(normal.maximize_winnr), "shared source buffer")
  local forks = assert(forked_winnrs)
  t.assert_eq(source_winnr, forks[1], "forked source window metadata")
  t.assert_eq(normal.maximize_winnr, forks[2], "forked maximize window metadata")
  t.assert_false(vim.t[source_tabnr].tabtype == enums.TabTypeEnum.MAXIMIZE, "open source tabtype")

  vim.api.nvim_win_set_buf(normal.maximize_winnr, final_bufnr)
  vim.api.nvim_win_set_cursor(normal.maximize_winnr, { 5, 0 })
  winnr_command = normal.maximize_winnr
  Maximize.toggle()

  t.assert_eq(source_tabnr, vim.api.nvim_get_current_tabpage(), "restored source tab")
  t.assert_eq(source_winnr, vim.api.nvim_get_current_win(), "restored source window")
  t.assert_eq(final_bufnr, vim.api.nvim_win_get_buf(source_winnr), "synced final buffer")
  t.assert_eq(5, vim.api.nvim_win_get_cursor(source_winnr)[1], "synced final view")
  t.assert_false(vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr), "closed maximize tab")
  t.assert_nil(maximized.get_normal(), "cleared normal context")
  t.assert_false(vim.t[source_tabnr].tabtype == enums.TabTypeEnum.MAXIMIZE, "source tabtype")
end)

t:test("leaving maximize closes it without stealing the selected tab", function()
  local source_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(source_winnr) ---@type integer
  local source_bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  vim.api.nvim_win_set_buf(source_winnr, source_bufnr)

  vim.cmd.tabnew()
  local destination_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[destination_tabnr].tabtype = enums.TabTypeEnum.NORMAL
  vim.api.nvim_set_current_tabpage(source_tabnr)
  register_cleanup(source_tabnr, source_winnr, original_bufnr, { source_bufnr }, { destination_tabnr })

  winnr_command = source_winnr
  Maximize.toggle()
  local normal = maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
  t.assert_true(normal ~= nil, "normal context")
  ---@cast normal dot.state.maximized.INormalContext

  vim.api.nvim_set_current_tabpage(destination_tabnr)
  t.wait_until(function()
    return not vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr) and maximized.get_normal() == nil
  end, 100, "maximize tab was not closed")

  t.assert_eq(destination_tabnr, vim.api.nvim_get_current_tabpage(), "selected tab focus")
  t.assert_true(vim.api.nvim_tabpage_is_valid(source_tabnr), "source tab")
  t.assert_false(vim.t[source_tabnr].tabtype == enums.TabTypeEnum.MAXIMIZE, "source tabtype")
end)

t:test("direct maximize tab close clears state without stealing focus", function()
  local source_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(source_winnr) ---@type integer
  local source_bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  vim.api.nvim_win_set_buf(source_winnr, source_bufnr)

  vim.cmd.tabnew()
  local destination_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[destination_tabnr].tabtype = enums.TabTypeEnum.NORMAL
  vim.api.nvim_set_current_tabpage(source_tabnr)
  register_cleanup(source_tabnr, source_winnr, original_bufnr, { source_bufnr }, { destination_tabnr })

  winnr_command = source_winnr
  Maximize.toggle()
  local normal = maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
  t.assert_true(normal ~= nil, "normal context")
  ---@cast normal dot.state.maximized.INormalContext

  vim.api.nvim_set_current_tabpage(destination_tabnr)
  local maximize_tabid = vim.api.nvim_tabpage_get_number(normal.maximize_tabnr) ---@type integer
  vim.api.nvim_cmd({ cmd = "tabclose", args = { tostring(maximize_tabid) } }, {})

  t.assert_false(vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr), "closed maximize tab")
  t.assert_nil(maximized.get_normal(), "cleared normal context")
  t.assert_eq(destination_tabnr, vim.api.nvim_get_current_tabpage(), "selected tab focus")
end)

t:test("explicit close clears state when TabClosed reports an error after closing", function()
  local source_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(source_winnr) ---@type integer
  local source_bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  register_cleanup(source_tabnr, source_winnr, original_bufnr, { source_bufnr })
  vim.api.nvim_win_set_buf(source_winnr, source_bufnr)

  winnr_command = source_winnr
  Maximize.toggle()
  local normal = maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
  t.assert_true(normal ~= nil, "normal context")
  ---@cast normal dot.state.maximized.INormalContext

  local error_group = vim.api.nvim_create_augroup("test_maximize_TabClosed_error", { clear = true }) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    pcall(vim.api.nvim_del_augroup_by_id, error_group)
  end)
  vim.api.nvim_create_autocmd("TabClosed", {
    group = error_group,
    callback = function()
      error("injected TabClosed failure")
    end,
  })

  Maximize.toggle()

  t.assert_false(vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr), "closed maximize tab")
  t.assert_nil(maximized.get_normal(), "cleared normal context")
  t.assert_eq(source_tabnr, vim.api.nvim_get_current_tabpage(), "restored source tab")
  t.assert_eq(1, #warnings, "reported TabClosed failure")
end)

t:test("float maximize reconfigures and restores the original window", function()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local source_winnr = vim.api.nvim_get_current_win() ---@type integer
  local source_bufnr = vim.api.nvim_win_get_buf(source_winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local float_winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 2,
    col = 3,
    width = 20,
    height = 5,
    border = "single",
  })
  register_cleanup(tabnr, source_winnr, source_bufnr, { bufnr })
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    if vim.api.nvim_win_is_valid(float_winnr) then
      vim.api.nvim_win_close(float_winnr, true)
    end
    maximized.clear_original_float()
  end)

  local original = vim.api.nvim_win_get_config(float_winnr) ---@type vim.api.keyset.win_config
  winnr_command = float_winnr
  Maximize.toggle()

  local maximized_cfg = vim.api.nvim_win_get_config(float_winnr) ---@type vim.api.keyset.win_config
  t.assert_true(maximized.get_original_float() ~= nil, "float context")
  t.assert_eq(tabnr, vim.api.nvim_get_current_tabpage(), "same tab")
  t.assert_true(maximized_cfg.width > original.width, "maximized width")

  Maximize.toggle()
  local restored = vim.api.nvim_win_get_config(float_winnr) ---@type vim.api.keyset.win_config

  t.assert_nil(maximized.get_original_float(), "cleared float context")
  t.assert_eq(original.relative, restored.relative, "restored relative")
  t.assert_eq(original.width, restored.width, "restored width")
  t.assert_eq(original.height, restored.height, "restored height")
end)

t:run()
