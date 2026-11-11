---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.picker" ---@type string

-- Picker and Searcher fixtures: composers built from the controls their specs share, their result surfaces and the
-- buffer Searcher. `tree_props` also serves child Neovim processes, which load this checkout's modules.

local M = {}

-- The controls a FiletreeComposer or TreeComposer starts with: an empty case-sensitive query over the whole tree.
local TREE_CONTROLS = {
  search_pattern = "",
  flag_foldempty = false,
  flag_fuzzy = false,
  flag_regex = false,
  flag_case_sensitive = true,
  flag_selected = false,
  flag_viewtype = "tree",
} ---@type table<string, unknown>

-- The controls a Searcher FiletreeComposer starts with: an empty case-sensitive query for up to 500 matches in the
-- `*.txt` files under `rootpath`.
local SEARCHER_CONTROLS = {
  excludes = {},
  flag_exclude = false,
  flag_foldempty = false,
  flag_gitignore = false,
  flag_limit_matches = true,
  flag_regex = false,
  flag_replace = false,
  flag_case_sensitive = true,
  flag_selected = false,
  flag_viewtype = "tree",
  includes = { "*.txt" },
  max_filesize = "1M",
  max_matches = 500,
  replace_pattern = "",
  rootpath = "",
  search_pattern = "",
} ---@type table<string, unknown>

---@param value                         unknown
---@return stl.c.Observable
function M.observable(value)
  return stl.c.Observable.from_value(value)
end

---Copies `props` with each of `controls` as an Observable: the one `props` gives, one of the plain value it gives, or
---one of the default.
---@param controls                      table<string, unknown>
---@param props                         table
---@return table
local function with_controls(controls, props)
  local result = {} ---@type table
  for key, value in pairs(props) do
    result[key] = value
  end
  for key, default in pairs(controls) do
    local value = result[key]
    if value == nil then
      result[key] = M.observable(vim.deepcopy(default))
    elseif getmetatable(value) ~= stl.c.Observable then
      result[key] = M.observable(value)
    end
  end
  return result
end

---Props of a FiletreeComposer or TreeComposer: `props`, whose filter controls may be plain values, over an empty
---case-sensitive query of the whole tree.
---@param props                         table
---@return table
function M.tree_props(props)
  return with_controls(TREE_CONTROLS, props)
end

---Creates a FiletreeComposer from `tree_props(props)`, disposed when the case ends.
---@param t                             __test__.support.Harness
---@param props                         table
---@return era.m.picker.FiletreeComposer
function M.filetree(t, props)
  local composer = era.m.picker.FiletreeComposer.new(M.tree_props(props))
  t:defer(function()
    composer:dispose()
    -- Disposal releases the views a turn later.
    vim.wait(20)
  end)
  return composer
end

---Creates a Searcher FiletreeComposer, disposed when the case ends, from `props`, whose controls may be plain values,
---over an empty case-sensitive query for up to 500 matches in `*.txt` files.
---@param t                             __test__.support.Harness
---@param props                         table
---@return era.m.searcher.FiletreeComposer
function M.searcher(t, props)
  local composer = era.m.searcher.FiletreeComposer.new(with_controls(SEARCHER_CONTROLS, props))
  t:defer(function()
    composer:dispose()
    -- Disposal releases the views a turn later.
    vim.wait(20)
  end)
  return composer
end

---Opens the result of `composer` in a borderless float of `width` by `height` at the top left of the editor.
---@param composer                      { result: era.view.PickerResult }
---@param width                         integer
---@param height                        integer
---@return integer
function M.show_result(composer, width, height)
  return composer.result:create_win(
    { border = "none", number = false, winhighlight = "" },
    { row = 0, col = 0, width = width, height = height }
  )
end

---The callback of the keymap that `description` describes among the result keymaps of `composer`, else among its
---finder keymaps.
---@param composer                      { result: { keymaps: stl.t.IKeymap[] }, finder: { keymaps: stl.t.IKeymap[] } }
---@param description                   string
---@return fun(): nil
function M.action(composer, description)
  for _, keymaps in ipairs({ composer.result.keymaps, composer.finder.keymaps }) do
    for _, keymap in ipairs(keymaps) do
      if keymap.desc == description then
        ---@diagnostic disable-next-line: return-type-mismatch
        return keymap.callback
      end
    end
  end
  error("missing action: " .. description, 2)
end

---Runs the copy action `description` from the result window of `composer` and asserts that its choices open one row
---below and four columns right of the result cursor.
---@param t                             __test__.support.Harness
---@param composer                      { result: era.view.PickerResult, finder: { keymaps: stl.t.IKeymap[] } }
---@param description                   string
---@return nil
function M.assert_copy_choices_at_cursor(t, composer, description)
  local result_winnr = assert(composer.result:get_winnr()) ---@type integer
  vim.api.nvim_set_current_win(result_winnr)
  -- A float opened with the intended offset from the same cursor gives the expected placement.
  local reference = t:window(t:buffer(), { relative = "cursor", row = 1, col = 4, width = 1, height = 1 })
  local expected = vim.api.nvim_win_get_config(reference)
  vim.api.nvim_win_close(reference, true)

  M.action(composer, description)()
  local popup = vim.api.nvim_get_current_win() ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(popup) then
      vim.api.nvim_win_close(popup, true)
    end
  end)
  t.assert_eq(stl.e.WinTypeEnum.SELECT, vim.w[popup].wintype, "the copy choices")
  local config = vim.api.nvim_win_get_config(popup)
  t.assert_eq(expected.relative, config.relative, "relative to the cursor")
  t.assert_eq(result_winnr, config.win, "anchored to the result window")
  t.assert_eq(expected.row, config.row, "one row below the cursor")
  t.assert_eq(expected.col, config.col, "four columns right of the cursor")
end

---Creates a ResultTree named `name` over `source`, disposed when the case ends, that labels each node with the `label`
---of its data unless `present` says otherwise.
---@param t                             __test__.support.Harness
---@param name                          string
---@param source                        era.view.ResultSource
---@param present                       ?fun(key: string, data: table): table
---@return era.view.ResultTree
function M.result_tree(t, name, source, present)
  local tree = require("era.view.result_tree").new({
    name = name,
    tree = source,
    present = present or function(_, data)
      return { label = data.label }
    end,
  })
  t:defer(function()
    tree:dispose()
  end)
  return tree
end

---Attaches a buffer Searcher, closed when the case ends, to a new window above that shows `lines` in a listed scratch
---buffer, and waits until it finds a match. `props` gives Observables or plain values for the controls, over a
---case-sensitive plain search that does not replace.
---@param t                             __test__.support.Harness
---@param lines                         string[]
---@param props                         table
---@return era.m.searcher.buffer.Searcher
---@return integer
function M.buffer_searcher(t, lines, props)
  local bufnr = t:buffer(lines, { listed = true, scratch = true })
  local winnr = t:window(bufnr, { split = "above" }, true)
  local searcher = require("era.m.searcher.buffer").new(with_controls({
    o_flag_fuzzy = false,
    o_flag_regex = false,
    o_flag_replace = false,
    o_flag_case_sensitive = true,
    o_search_pattern = "",
    o_replace_pattern = "",
  }, props))
  t:defer(function()
    searcher:close()
  end)
  searcher:attach(winnr)
  t.wait_until(function()
    return searcher.o_match_total:snapshot() > 0
  end, 5000, "the search found no match")
  return searcher, bufnr
end

return M
