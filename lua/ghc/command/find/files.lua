local statusline = require("ghc.ui.statusline")
local session = require("ghc.context.session")
local util_find_scope = require("ghc.util.find.scope")

---@class ghc.command.find
local M = require("ghc.command.find.mod")

local _select = nil ---@type fml.types.ui.select.ISelect|nil
local _uuid = "eba42821-7a63-42b8-91bd-43a8005f2c91" ---@type string
local _filepath = fml.path.locate_session_filepath({ filename = "select-" .. _uuid .. ".json" }) ---@type string

local state_dirpath = fml.collection.Observable.from_value(vim.fn.expand("%:p:h")) ---@type fml.collection.Observable
local state_find_cwd = fml.collection.Observable.from_value("") ---@type fml.collection.Observable

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if _select ~= nil then
      local data = _select.state:dump() ---@type fml.types.ui.select.state.ISerializedData
      fml.fs.write_json(_filepath, data)
    end
  end,
})

---@param scope                         ghc.enums.context.FindScope
---@return nil
local function change_scope(scope)
  local scope_current = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  if _select ~= nil and scope_current ~= scope then
    session.find_scope:next(scope)
    local dirpath = state_dirpath:snapshot() ---@type string
    local find_cwd = util_find_scope.get_cwd(scope, dirpath) ---@type string
    state_find_cwd:next(find_cwd)
    M.reload()
  end
end

---@return nil
function M.reload()
  if _select ~= nil then
    local find_cwd = state_find_cwd:snapshot() ---@type string
    local paths = fml.oxi.collect_file_paths(find_cwd, {
      ".cache/**",
      ".git/**",
      ".yarn/**",
      "**/build/**",
      "**/debug/**",
      "**/node_modules/**",
      "**/target/**",
      "**/tmp/**",
      "**/*.pdf",
      "**/*.mkv",
      "**/*.mp4",
      "**/*.zip",
    })
    local items = {} ---@type fml.types.ui.select.IItem[]
    for _, path in ipairs(paths) do
      local item = { uuid = path, display = path, lower = path:lower() } ---@type fml.types.ui.select.IItem
      table.insert(items, item)
    end
    table.sort(items, function(a, b)
      return a.display < b.display
    end)
    _select.state:update_items(items)
  end
end

---@return fml.types.ui.select.ISelect
local function get_select()
  if _select == nil then
    local actions = {
      change_scope_workspace = function()
        change_scope("W")
      end,
      change_scope_cwd = function()
        change_scope("C")
      end,
      change_scope_directory = function()
        change_scope("D")
      end,
      change_scope_carousel = function()
        ---@type ghc.enums.context.FindScope
        local scope = ghc.context.session.find_scope:snapshot()
        local scope_next = util_find_scope.get_carousel_next(scope)
        change_scope(scope_next)
      end,
    }

    ---@type fml.types.IKeymap[]
    local input_keymaps = {
      {
        modes = { "n", "v" },
        key = "<leader>w",
        callback = actions.change_scope_workspace,
        desc = "find: change scope (workspace)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>c",
        callback = actions.change_scope_cwd,
        desc = "find: change scope (cwd)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>d",
        callback = actions.change_scope_directory,
        desc = "find: change scope (directory)",
      },
      {
        modes = { "n", "v" },
        key = "<leader>s",
        callback = actions.change_scope_carousel,
        desc = "find: change scope (carousel)",
      },
    }

    ---@type fml.types.IKeymap[]
    local main_keymaps = vim.tbl_deep_extend("force", {}, input_keymaps)

    _select = fml.ui.select.Select.new({
      state = fml.ui.select.State.new({
        title = "Select file",
        uuid = _uuid,
        items = {},
        input = fml.collection.Observable.from_value(""),
        visible = fml.collection.Observable.from_value(false),
      }),
      width = 0.4,
      height = 0.5,
      render_line = fml.ui.select.defaults.render_filepath,
      input_keymaps = input_keymaps,
      main_keymaps = main_keymaps,
      on_close = function()
        statusline.disable(statusline.cnames.find_files)
      end,
      on_confirm = function(item)
        local winnr = fml.api.state.win_history:present() ---@type integer
        if winnr ~= nil then
          local cwd = state_find_cwd:snapshot() ---@type string
          local filepath = fml.path.join(cwd, item.display) ---@type string
          vim.schedule(function()
            fml.api.buf.open(winnr, filepath)
          end)
          return true
        end
        return false
      end,
    })

    local data = fml.fs.read_json({ filepath = _filepath, silent_on_bad_path = true, silent_on_bad_json = false })
    if data ~= nil then
      _select.state:load(data)
    end
  end

  local scope = session.find_scope:snapshot() ---@type ghc.enums.context.FindScope
  local find_cwd = util_find_scope.get_cwd(scope, state_dirpath:snapshot()) ---@type string
  state_find_cwd:next(find_cwd)
  M.reload()

  return _select
end

---@return nil
function M.files()
  state_dirpath:next(vim.fn.expand("%:p:h"))
  local select = get_select() ---@type fml.types.ui.select.ISelect
  statusline.enable(statusline.cnames.find_files)
  select:open()
end
