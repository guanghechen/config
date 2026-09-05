--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/diffview/scroll_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.m.diffview.scroll")

local layout = assert(loadfile("lua/era/m/diffview/layout.lua"))()

---@param keymaps                       stl.t.IKeymap[]
---@param key                           string
---@return stl.t.IKeymap|nil
local function find_keymap(keymaps, key)
  for _, keymap in ipairs(keymaps) do
    if keymap.key == key then
      return keymap
    end
  end
end

---@param keymaps                       stl.t.IKeymap[]
---@param key                           string
---@return boolean
local function has_keymap(keymaps, key)
  return find_keymap(keymaps, key) ~= nil
end

---@param bufnr                         integer
---@param key                           string
---@return boolean
local function has_buffer_keymap(bufnr, key)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if keymap.lhs == key then
      return true
    end
  end
  return false
end

t:test("mouse scroll keeps focus and routes through the hovered window", function()
  local panel_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnrs = {} ---@type integer[]
  local original_panel_bufnr = vim.api.nvim_win_get_buf(panel_winnr) ---@type integer

  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    for _, winnr in ipairs({ right_winnr, left_winnr }) do
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end
    for _, bufnr in ipairs(bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    if vim.api.nvim_win_is_valid(panel_winnr) then
      vim.api.nvim_set_current_win(panel_winnr)
      if vim.api.nvim_buf_is_valid(original_panel_bufnr) then
        vim.api.nvim_win_set_buf(panel_winnr, original_panel_bufnr)
      end
    end
  end)

  local lines = {} ---@type string[]
  for i = 1, 200 do
    lines[i] = string.format("line %03d", i)
  end

  for _, winnr in ipairs({ panel_winnr, left_winnr, right_winnr }) do
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    bufnrs[#bufnrs + 1] = bufnr
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_set_option_value("scrolloff", 0, { win = winnr, scope = "local" })
  end
  vim.api.nvim_set_option_value("scrollbind", true, { win = left_winnr, scope = "local" })
  vim.api.nvim_set_option_value("scrollbind", true, { win = right_winnr, scope = "local" })

  local mouse_winnr = right_winnr ---@type integer
  t:patch_table(vim.fn, "getmousepos", function()
    return { winid = mouse_winnr }
  end)
  vim.api.nvim_set_current_win(panel_winnr)
  layout.scroll_mouse("down")

  local left_view = vim.api.nvim_win_call(left_winnr, vim.fn.winsaveview)
  local right_view = vim.api.nvim_win_call(right_winnr, vim.fn.winsaveview)
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus")
  t.assert_true(left_view.topline > 1, "left scrolled")
  t.assert_eq(left_view.topline, right_view.topline, "bound windows")

  local down_topline = left_view.topline
  layout.scroll_mouse("up")
  left_view = vim.api.nvim_win_call(left_winnr, vim.fn.winsaveview)
  right_view = vim.api.nvim_win_call(right_winnr, vim.fn.winsaveview)
  t.assert_true(left_view.topline < down_topline, "hovered sbs scrolled up")
  t.assert_eq(left_view.topline, right_view.topline, "bound windows after up")

  mouse_winnr = panel_winnr
  local sbs_topline = left_view.topline
  layout.scroll_mouse("down")

  local panel_view = vim.api.nvim_win_call(panel_winnr, vim.fn.winsaveview)
  left_view = vim.api.nvim_win_call(left_winnr, vim.fn.winsaveview)
  right_view = vim.api.nvim_win_call(right_winnr, vim.fn.winsaveview)
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after panel scroll")
  t.assert_true(panel_view.topline > 1, "hovered panel scrolled")
  t.assert_eq(sbs_topline, left_view.topline, "left sbs unchanged")
  t.assert_eq(sbs_topline, right_view.topline, "right sbs unchanged")

  mouse_winnr = 0
  local panel_topline = panel_view.topline
  layout.scroll_mouse("down")
  panel_view = vim.api.nvim_win_call(panel_winnr, vim.fn.winsaveview)
  t.assert_eq(panel_topline, panel_view.topline, "no window under mouse")
end)

t:test("panel buffers route mouse scrolling without leaking mappings to side-by-side buffers", function()
  local calls = {} ---@type string[]
  local action = {
    scroll_mouse = function(direction)
      calls[#calls + 1] = direction
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", action)
  t:patch_table(package.loaded, "era.m.git.visual", {})

  local workspace_keymap = assert(loadfile("lua/era/m/diffview/view/workspace/keymap.lua"))()
  ---@diagnostic disable-next-line: missing-fields
  local ctx = {} ---@type era.m.diffview.view.workspace.IContext
  local workspace_panel_keymaps = workspace_keymap.gen_changes(ctx)
  assert(find_keymap(workspace_panel_keymaps, "<ScrollWheelDown>")).callback()
  assert(find_keymap(workspace_panel_keymaps, "<ScrollWheelUp>")).callback()
  t.assert_false(has_keymap(workspace_panel_keymaps, "<C-d>"), "workspace keyboard down")
  t.assert_false(has_keymap(workspace_panel_keymaps, "<C-u>"), "workspace keyboard up")
  local workspace_sbs_keymaps = workspace_keymap.gen_sbs(ctx)
  t.assert_false(has_keymap(workspace_sbs_keymaps, "<ScrollWheelDown>"), "workspace sbs wheel down")
  t.assert_false(has_keymap(workspace_sbs_keymaps, "<ScrollWheelUp>"), "workspace sbs wheel up")
  t.assert_eq("down,up", table.concat(calls, ","), "workspace scroll directions")

  calls = {}
  t:patch_table(package.loaded, "era.m.diffview.view.commits.action", action)
  t:patch_table(package.loaded, "era.m.diffview.pane.commits", {})

  local commits_keymap = assert(loadfile("lua/era/m/diffview/view/commits/keymap.lua"))()
  ---@diagnostic disable-next-line: missing-fields
  local commits_ctx = {} ---@type era.m.diffview.view.commits.IContext
  for _, keymaps in ipairs({ commits_keymap.gen_commits(commits_ctx), commits_keymap.gen_filetree(commits_ctx) }) do
    assert(find_keymap(keymaps, "<ScrollWheelDown>")).callback()
    assert(find_keymap(keymaps, "<ScrollWheelUp>")).callback()
    t.assert_false(has_keymap(keymaps, "<C-d>"), "commits keyboard down")
    t.assert_false(has_keymap(keymaps, "<C-u>"), "commits keyboard up")
  end
  local commits_sbs_keymaps = commits_keymap.gen_sbs(commits_ctx)
  t.assert_false(has_keymap(commits_sbs_keymaps, "<ScrollWheelDown>"), "commits sbs wheel down")
  t.assert_false(has_keymap(commits_sbs_keymaps, "<ScrollWheelUp>"), "commits sbs wheel up")
  t.assert_eq("down,up,down,up", table.concat(calls, ","), "commits scroll directions")

  local shared_sbs_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    if vim.api.nvim_buf_is_valid(shared_sbs_bufnr) then
      vim.api.nvim_buf_delete(shared_sbs_bufnr, { force = true })
    end
  end)
  local sbs_keymap = assert(loadfile("lua/era/m/diffview/view/sbs_keymap.lua"))()
  t:patch_table(package.loaded, "era.m.diffview.view.sbs_keymap", sbs_keymap)
  workspace_keymap.setup_sbs(ctx, shared_sbs_bufnr)
  commits_keymap.setup_sbs(commits_ctx, shared_sbs_bufnr)
  t.assert_false(has_buffer_keymap(shared_sbs_bufnr, "<ScrollWheelDown>"), "shared sbs wheel mapping")
end)

t:test("commits panel recreation installs mouse mappings", function()
  local created_bufnrs = {} ---@type integer[]
  local function create_buffer()
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    created_bufnrs[#created_bufnrs + 1] = bufnr
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    return bufnr
  end

  t:patch_table(package.loaded, "era.m.diffview.config", {
    COMMITS_WIDTH = 20,
    FILETREE_WIDTH = 20,
  })
  t:patch_table(package.loaded, "era.m.diffview.layout", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.commits", {
    apply_winopts = function() end,
    create_buffer = create_buffer,
    goto_last_child_or_sibling = function() end,
    goto_parent_node = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.pane.filetree", {
    apply_winopts = function() end,
    create_buffer = create_buffer,
  })
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
  t:patch_table(package.loaded, "era.m.diffview.view.commits.action", {
    scroll_mouse = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.keymap", nil)

  local view = assert(loadfile("lua/era/m/diffview/view/commits/view.lua"))()
  local anchor_winnr = vim.api.nvim_get_current_win() ---@type integer
  local ctx = {
    layout = {
      tabnr = vim.api.nvim_get_current_tabpage(),
      commits_winnr = nil,
      commits_bufnr = nil,
      filetree_winnr = nil,
      filetree_bufnr = nil,
      sbs_left_winnr = anchor_winnr,
      sbs_right_winnr = nil,
    },
    state = {},
  } ---@type era.m.diffview.view.commits.IContext

  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    if vim.api.nvim_win_is_valid(anchor_winnr) then
      vim.api.nvim_set_current_win(anchor_winnr)
    end
    for _, winnr in ipairs({ ctx.layout.filetree_winnr, ctx.layout.commits_winnr }) do
      if winnr and vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end
    for _, bufnr in ipairs(created_bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)

  view.show_commits(ctx)
  local first_commits_bufnr = assert(ctx.layout.commits_bufnr) ---@type integer
  t.assert_true(has_buffer_keymap(first_commits_bufnr, "<ScrollWheelDown>"), "initial commits mapping")
  view.hide_commits(ctx.layout)
  t.assert_false(vim.api.nvim_buf_is_valid(first_commits_bufnr), "hidden commits buffer wiped")
  view.show_commits(ctx)
  t.assert_true(has_buffer_keymap(assert(ctx.layout.commits_bufnr), "<ScrollWheelDown>"), "recreated commits mapping")

  view.show_filetree(ctx)
  local first_filetree_bufnr = assert(ctx.layout.filetree_bufnr) ---@type integer
  t.assert_true(has_buffer_keymap(first_filetree_bufnr, "<ScrollWheelDown>"), "initial filetree mapping")
  view.hide_filetree(ctx.layout)
  t.assert_false(vim.api.nvim_buf_is_valid(first_filetree_bufnr), "hidden filetree buffer wiped")
  view.show_filetree(ctx)
  t.assert_true(has_buffer_keymap(assert(ctx.layout.filetree_bufnr), "<ScrollWheelDown>"), "recreated filetree mapping")
end)

t:run()
