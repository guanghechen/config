---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.cmp.embedded" ---@type string

local Grid = require("__test__.support.ui_grid")
local UI = require("__test__.support.ui")

---@class __test__.support.cmp.embedded.ICell
---@field row                           integer
---@field col                           integer
---@field text                          string
---@field attribute                     integer
---@field style                         ?table The highlight of a matched character.

---@class __test__.support.cmp.embedded.IMenu
---@field geometry                      table What `pum_getpos()` returns.
---@field rows                          string[] Screen text over the menu and its scrollbar.
---@field cells                         __test__.support.cmp.embedded.ICell[]
---@field selected                      integer
---@field windows                       integer
---@field thumb                         __test__.support.cmp.embedded.ICell[] Cells on the 0x2b2b2b thumb background.
---@field matches                       __test__.support.cmp.embedded.ICell[] Cells in the 0xf5a9b8 match color.

local M = {}

---Starts a child Neovim with the completion runtime over `lines`, the cursor on the last line. The child closes, and
---must have reported no error, when `t` cleans up.
---@param t                             __test__.support.Harness
---@param lines                         string[]
---@return __test__.support.UI
function M.editor(t, lines)
  local ui = UI.open(t, {})
  ui:lua(
    [[
    local lines = ...
    require('__test__.support.cmp.runtime').setup()
    vim.api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { #lines, 0 })
    require('era.keystroke.cmp').setup()
  ]],
    lines
  )
  t:defer(function()
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
  end)
  return ui
end

---Installs a fake LSP client in the child. `complete` and `resolve` are Lua chunks returning the completion handler
---`fun(params, callback)` and the resolve handler `fun(item): item, delay_ms?`; requests and executed commands are
---recorded in `_G.cmp_requests` and `_G.cmp_commands`.
---@param ui                            __test__.support.UI
---@param complete                      string
---@param resolve                       ?string
---@return nil
function M.lsp_client(ui, complete, resolve)
  ui:lua(
    [[
    local complete_code, resolve_code = ...
    local completion = assert(loadstring(complete_code))()
    local resolve = resolve_code and assert(loadstring(resolve_code))() or function(item) return item end
    _G.cmp_requests = {}
    _G.cmp_commands = {}
    local client = {
      id = 9001, name = 'completion-fixture', offset_encoding = 'utf-16',
      server_capabilities = { completionProvider = { resolveProvider = true, triggerCharacters = { '.' } } },
      cancel_request = function() end,
      exec_cmd = function(_, command) cmp_commands[#cmp_commands + 1] = command end,
    }
    function client:request(method, params, callback, bufnr)
      cmp_requests[#cmp_requests + 1] = { method = method, params = params, bufnr = bufnr }
      local id = #cmp_requests
      if method == 'textDocument/completion' then
        completion(params, callback)
      elseif method == 'completionItem/resolve' then
        local result, delay = resolve(params)
        vim.defer_fn(function() callback(nil, result) end, delay or 0)
      end
      return true, id
    end
    vim.lsp.get_clients = function(filter)
      return filter and filter.method == 'textDocument/completion' and { client } or {}
    end
    vim.lsp.get_client_by_id = function(id) return id == client.id and client or nil end
  ]],
    complete,
    resolve
  )
end

---Starts a child Neovim attached at `start` (100x35 by default) with the behavior editor set up from `options`, and
---a grid that follows its screen.
---@param t                             __test__.support.Harness
---@param options                       table The options of `__test__.support.cmp.behavior.setup`.
---@param start                         ?__test__.support.ui.IStart
---@return __test__.support.UI
---@return table grid
function M.behavior_editor(t, options, start)
  local ui = UI.open(t)
  local grid = Grid.new(ui)
  ui:start(start or { width = 100, height = 35 })
  ui:lua([[require('__test__.support.cmp.behavior').setup(...)]], options)
  return ui, grid
end

---Starts `behavior_editor` from `options` under the vsc-dark-modern theme, without menu blending, once the deprecated
---label highlight is checked to only decorate. The child must have reported no error when `t` cleans up.
---@param t                             __test__.support.Harness
---@param options                       table The options of `__test__.support.cmp.behavior.setup`.
---@return __test__.support.UI
---@return table grid
function M.themed_editor(t, options)
  local ui, grid = M.behavior_editor(t, options)
  ui:lua([[
    local deprecated = vim.api.nvim_get_hl(0,{name='CmpLabelDeprecated',link=false})
    assert(deprecated.strikethrough and deprecated.fg == nil and deprecated.bg == nil,'decoration-only fallback')
    local cmp_stl, cmp_dot = stl, dot
    stl, dot = require('stl'), require('dot')
    dot.context.theme.apply_theme({theme='vsc-dark-modern',transparency=false})
    stl, dot = cmp_stl, cmp_dot
    vim.o.pumblend = 0
  ]])
  t:defer(function()
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
  end)
  return ui, grid
end

---Waits until the Lua chunk `code` holds in the child; a failure shows the buffer and the mode.
---@param t                             __test__.support.Harness
---@param ui                            __test__.support.UI
---@param code                          string
---@param message                       string
---@return nil
function M.wait(t, ui, code, message)
  local ok = pcall(ui.wait_lua, ui, code, 5000)
  if not ok then
    message = message
      .. ": "
      .. vim.inspect(ui:lua([[return {lines=vim.api.nvim_buf_get_lines(0,0,-1,false),mode=vim.api.nvim_get_mode()}]]))
  end
  t.assert_true(ok, message)
end

---Reads the screen around the visible popup menu of `ui`, past its border and scrollbar, with the highlights `grid`
---resolves.
---@param ui                            __test__.support.UI
---@param grid                          table
---@return __test__.support.cmp.embedded.IMenu
function M.menu(ui, grid)
  local state = ui:lua([[
    local geometry = vim.fn.pum_getpos()
    local rows, cells = {}, {}
    if vim.fn.pumvisible() == 1 then
      for row = math.max(1, geometry.row), math.min(vim.o.lines, geometry.row + geometry.height + 3) do
        local text = {}
        for col = math.max(1, geometry.col), math.min(vim.o.columns, geometry.col + geometry.width + 4) do
          local character = vim.fn.screenstring(row,col)
          text[#text + 1] = character
          cells[#cells + 1] = {row=row,col=col,text=character,attribute=vim.fn.screenattr(row,col)}
        end
        rows[#rows + 1] = table.concat(text)
      end
    end
    return {geometry=geometry,rows=rows,cells=cells,selected=vim.fn.complete_info({'selected'}).selected,windows=#vim.api.nvim_list_wins()}
  ]])
  state.thumb = {}
  state.matches = {}
  for _, cell in ipairs(state.cells) do
    local attribute = grid.highlights[cell.attribute] or {}
    if attribute.background == 0x2b2b2b then
      state.thumb[#state.thumb + 1] = cell
    end
    if attribute.foreground == 0xf5a9b8 then
      cell.style = attribute
      state.matches[#state.matches + 1] = cell
    end
  end
  return state
end

---Requires the matched characters of a menu filtered by "ap" to be its "a" and "p" on each row in turn, bold and
---italic over the background of the selected row (0-based) or of the others.
---@param t                             __test__.support.Harness
---@param matches                       __test__.support.cmp.embedded.ICell[]
---@param selected                      integer
---@return nil
function M.assert_matches(t, matches, selected)
  for index, cell in ipairs(matches) do
    t.assert_eq(index % 2 == 1 and "a" or "p", cell.text, "only query letters are highlighted")
    t.assert_true(cell.style.bold and cell.style.italic, "matching letters retain bold and italic")
    t.assert_eq(
      math.floor((index - 1) / 2) == selected and 0x0078d4 or 0x1f1f1f,
      cell.style.background,
      "selected and unselected menu backgrounds remain intact"
    )
  end
end

---Waits until the completion menu lists an item whose abbreviation contains `text`.
---@param ui                            __test__.support.UI
---@param text                          string
---@param message                       string
---@return nil
function M.wait_menu_item(ui, text, message)
  ui:wait_lua(
    [[
    local text = ...
    for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do
      if item.abbr:find(text, 1, true) then return true end
    end
    return false
  ]],
    5000,
    message,
    text
  )
end

---Accepts the selected candidate through the completion API and waits until the acceptance requests its resolve.
---@param ui                            __test__.support.UI
---@return nil
function M.accept_resolving(ui)
  ui:lua([[
    _G.cmp_before_accept_request = #cmp_requests
    assert(require('era.keystroke.cmp').accept())
  ]])
  ui:wait_lua(
    [[
    for index = cmp_before_accept_request + 1, #cmp_requests do
      if cmp_requests[index].method == 'completionItem/resolve' then return true end
    end
    return false
  ]],
    5000,
    "native acceptance reached resolve"
  )
end

return M
