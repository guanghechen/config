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

---Creates a FiletreeComposer named `name` as `filetree` does, not permanent, without a preview and titled "filetree
---test", that calls the callbacks given.
---@param t                             __test__.support.Harness
---@param name                          string
---@param on_attached                   ?fun(_: era.m.picker.FiletreeComposer, rootpath: string)
---@param on_confirm                    ?era.m.picker.composer.filetree.IOnConfirm
---@param on_preview_rendered           ?era.m.picker.composer.filetree.IOnPreviewRendered
---@return era.m.picker.FiletreeComposer
function M.filetree_composer(t, name, on_attached, on_confirm, on_preview_rendered)
  return M.filetree(t, {
    name = name,
    permanent = false,
    preview = false,
    title = "filetree test",
    on_attached = on_attached,
    on_confirm = on_confirm,
    on_preview_rendered = on_preview_rendered,
  })
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

---Creates a ResultTree, disposed when the case ends, whose container `root` holds the container `dir`, which holds the
---leaves `one` and `two`, and the leaf `three`. Each node is labelled with its key, as each leaf's text is.
---@param t                             __test__.support.Harness
---@return era.view.ResultTree
function M.branch_tree(t)
  local source = require("era.view.result_source").new("root", { label = "root" })
  source:insert("root", "dir", { label = "dir" })
  source:insert("dir", "one", { label = "one" })
  source:insert("dir", "two", { label = "two" })
  source:insert("root", "three", { label = "three" })
  local tree = M.result_tree(t, "native results", source)
  tree:insert("root", { nodetype = "container" })
  tree:insert("dir", { nodetype = "container" })
  for _, key in ipairs({ "one", "two", "three" }) do
    tree:insert(key, { nodetype = "leaf", text = key })
  end
  return tree
end

---Creates a ResultTree, disposed when the case ends, whose container `root` holds the container `dir`, labelled
---"directory", which holds the leaf `file`, labelled "file.lua".
---@param t                             __test__.support.Harness
---@return era.view.ResultTree
function M.file_tree(t)
  local source = require("era.view.result_source").new("root", { label = "root" })
  source:insert("root", "dir", { label = "directory" })
  source:insert("dir", "file", { label = "file.lua" })
  local tree = M.result_tree(t, "native picker", source)
  tree:insert("root", { nodetype = "container" })
  tree:insert("dir", { nodetype = "container" })
  tree:insert("file", { nodetype = "leaf" })
  return tree
end

---Starts a child UI, closed when the case ends, whose global `picker` is a permanent ListComposer focused on `items`:
---"needle first", whose payload is `original`, "needle second" and "other", each label prefixed with "中:". Its filter
---`controls` start as an empty plain case-insensitive query. `errors` collects the reported errors, `writes` counts the
---writes to the result buffer and `matches` holds the columns of the match highlight drawn on each result row.
---@param t                             __test__.support.Harness
---@return __test__.support.UI
function M.list_ui(t)
  local ui = require("__test__.support.ui").open(t, { width = 100, height = 32, runtime = "ark" })
  ui:lua([[
    errors = {}
    stl.reporter.error = function(value) errors[#errors + 1] = value end
    controls = {
      search_pattern = stl.c.Observable.from_value(""),
      flag_fuzzy = stl.c.Observable.from_value(false),
      flag_regex = stl.c.Observable.from_value(false),
      flag_case_sensitive = stl.c.Observable.from_value(false),
    }
    original = {opaque = newproxy(false)}
    items = {
      {uuid="one", text="needle first", text_lower="needle first", data=original},
      {uuid="two", text="needle second", text_lower="needle second", data={}},
      {uuid="three", text="other", text_lower="other", data={}},
    }
    picker = era.m.picker.ListComposer.new(vim.tbl_extend("force", controls, {
      name="native list", title="native list", permanent=true,
      present=function(_, item)
        local prefix="中:"
        return {label=prefix..item.text, match_regions={{0, #item.text, #prefix}}}
      end,
    }))
    writes, matches = 0, {}
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(bufnr, ...)
      if bufnr == picker.result:get_bufnr() then writes = writes + 1 end
      return set_lines(bufnr, ...)
    end
    local set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, nsnr, row, col, options)
      if bufnr == picker.result:get_bufnr() and options.ephemeral and options.hl_group == "TreeviewMatch" then
        matches[row] = {col, options.end_col}
      end
      return set_extmark(bufnr, nsnr, row, col, options)
    end
    picker:reset_data({items=items, uuid_current="one", uuid_present="two"})
    picker:focus()
  ]])
  ui:wait_lua(
    "return picker._treeview.view and picker._treeview.view:frame() and picker._treeview:linecount() == 3",
    5000,
    "three rows"
  )
  return ui
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

-- Case-insensitive "needle" matches five times in the files of `replace_fixture`: once in the first line of alpha,
-- twice in its second and twice in beta.
M.REPLACE_FILES = {
  ["alpha.txt"] = { "needle one", "a needle and a Needle", "nothing here" },
  ["beta.txt"] = { "NEEDLE upper", "needle" },
} ---@type table<string, string[]>

---@class __test__.support.picker.IReplaceControls
---@field public search_pattern         stl.c.Observable
---@field public replace_pattern        stl.c.Observable
---@field public flag_regex             stl.c.Observable
---@field public flag_replace           stl.c.Observable

local replace_count = 0 ---@type integer

---Writes `REPLACE_FILES` to a directory of the case, removed when it ends, so a case that writes files leaves the
---others alone.
---@param t                             __test__.support.Harness
---@return string
function M.replace_fixture(t)
  local dir = t:tempdir()
  for name, lines in pairs(M.REPLACE_FILES) do
    vim.fn.writefile(lines, vim.fs.joinpath(dir, name))
  end
  return dir
end

---Creates a Searcher FiletreeComposer over `dir` as `searcher` does, case-insensitive and in replace mode, that searches
---again on a refresh as Search Files does, and shows its result. The query and the replacement start empty.
---@param t                             __test__.support.Harness
---@param dir                           string
---@return era.m.searcher.FiletreeComposer
---@return __test__.support.picker.IReplaceControls
function M.replace_composer(t, dir)
  replace_count = replace_count + 1
  local controls = {
    search_pattern = M.observable(""),
    replace_pattern = M.observable(""),
    flag_regex = M.observable(false),
    flag_replace = M.observable(true),
  } ---@type __test__.support.picker.IReplaceControls
  local composer = M.searcher(t, {
    name = "replacement-" .. replace_count,
    permanent = false,
    preview = false,
    title = "replacement test",
    flag_regex = controls.flag_regex,
    flag_replace = controls.flag_replace,
    flag_case_sensitive = false,
    replace_pattern = controls.replace_pattern,
    rootpath = dir,
    search_pattern = controls.search_pattern,
    -- As Search Files does.
    on_refresh = function(composer)
      composer:schedule_search()
    end,
  })
  M.show_result(composer, 80, 10)
  require("__test__.support.treeview").await(composer._treeview:ready())
  return composer, controls
end

---Waits until no search of `composer` runs and its published projection reflects the current inputs, and until
---`predicate` holds when given.
---@param composer                      era.m.searcher.FiletreeComposer
---@param msg                           string
---@param predicate                     ?fun(): boolean
---@return nil
function M.settle_search(composer, msg, predicate)
  require("__test__.support.harness").wait_until(function()
    return composer._file_search._active == nil
      and composer:__is_search_projection_current__()
      and (predicate == nil or predicate())
  end, 5000, msg)
end

---Searches "needle" with `replacement` through the controls of `replace_composer` and waits until it publishes.
---@param composer                      era.m.searcher.FiletreeComposer
---@param controls                      __test__.support.picker.IReplaceControls
---@param replacement                   string
---@return nil
function M.search_needle(composer, controls, replacement)
  controls.replace_pattern:next(replacement)
  controls.search_pattern:next("needle")
  M.settle_search(composer, "the first search did not publish")
end

return M
