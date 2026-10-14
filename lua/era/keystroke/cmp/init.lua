---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp" ---@type string

local Context = require("era.keystroke.cmp.context")
local Keymap = require("era.keystroke.cmp.keymap")
local Cmdline = require("era.keystroke.cmp.cmdline")
local initialized = false
local session ---@type era.keystroke.cmp.Session|nil
local attached = {} ---@type table<integer, boolean>

---@class era.keystroke.cmp
local M = {}

---@return era.keystroke.cmp.Session
local function get_session()
  if session == nil then
    local Path = require("era.keystroke.cmp.source.path")
    session = require("era.keystroke.cmp.session").new({
      sources = {
        lsp = require("era.keystroke.cmp.source.lsp"),
        path = Path,
        path_at = Path,
        snippets = require("era.keystroke.cmp.source.snippets"),
        buffer = require("era.keystroke.cmp.source.buffer"),
        dict = require("era.keystroke.cmp.source.dict"),
        slash = require("era.keystroke.cmp.source.slash"),
      },
      sources_for = require("era.keystroke.cmp.policy").sources_for,
      frecency = dot.context.frecency.completions,
    })
  end
  return session
end

---@return nil
local function highlights()
  local links = {
    CmpLabelDeprecated = "Comment",
    CmpDoc = "NormalFloat",
    CmpDocBorder = "FloatBorder",
    CmpDocSeparator = "NormalFloat",
    CmpSignatureHelp = "NormalFloat",
    CmpSignatureHelpBorder = "FloatBorder",
    CmpSignatureHelpActiveParameter = "LspSignatureActiveParameter",
  }
  for _, kind in ipairs(vim.lsp.protocol.CompletionItemKind) do
    links["CmpKind" .. kind] = "Identifier"
  end
  for name, link in pairs(links) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

---@param bufnr                         integer
---@return nil
local function invalidate_buffer(bufnr)
  Context.invalidate(bufnr)
  if session ~= nil then
    session:on_buffer_invalidated(bufnr)
  end
end

---@param bufnr                         integer
---@return nil
local function attach(bufnr)
  Keymap.bind_insert(bufnr, get_session)
  if attached[bufnr] then
    return
  end
  attached[bufnr] = vim.api.nvim_buf_attach(bufnr, false, {
    on_bytes = function(_, changed_bufnr, _, row, col, _, old_rows, old_cols, _, new_rows, new_cols)
      if session ~= nil then
        session:on_bytes(changed_bufnr, row, col, old_rows, old_cols, new_rows, new_cols)
      end
    end,
    on_reload = function(_, reloaded_bufnr)
      invalidate_buffer(reloaded_bufnr)
    end,
    on_detach = function(_, detached_bufnr)
      attached[detached_bufnr] = nil
      invalidate_buffer(detached_bufnr)
      Context.forget(detached_bufnr)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(detached_bufnr) and vim.api.nvim_buf_is_loaded(detached_bufnr) then
          attach(detached_bufnr)
        end
      end)
    end,
  })
end

---@return nil
function M.setup()
  if initialized or vim.g.vscode or vim.g.yozvim or vim.g.yuivim then
    return
  end
  initialized = true
  vim.o.completeopt = "menuone,noselect,popup"
  vim.o.completeitemalign = "kind,abbr,menu"
  vim.o.pumborder = "rounded"
  vim.o.pumheight = 10
  vim.o.pummaxwidth = 88
  vim.o.wildoptions = "pum,fuzzy"
  highlights()
  vim.lsp.commands["editor.action.triggerSuggest"] = function(_, params)
    local context = Context.capture("manual")
    if context ~= nil and context.bufnr == params.bufnr and Context.enabled(context) then
      get_session():show()
    end
  end
  vim.lsp.commands["editor.action.triggerParameterHints"] = function(_, params)
    local context = Context.capture("manual")
    if context ~= nil and context.bufnr == params.bufnr and Context.enabled(context) then
      get_session().signature:update(context, true)
    end
  end
  local group = stl.nvim.fn.augroup(__module_name__)
  local queued = false
  local trigger = "move"
  local backspace = false
  local cmdline_typing = false
  local backspace_key = vim.keycode("<BS>")
  vim.on_key(function(key, typed)
    backspace = key == backspace_key or key == "\b"
    if vim.api.nvim_get_mode().mode == "c" then
      local translated = vim.fn.keytrans(typed)
      cmdline_typing = backspace
        or (
          typed ~= ""
          and (
            translated:sub(1, 1) ~= "<"
            or key == " "
            or translated == "<C-W>"
            or translated == "<C-U>"
            or translated == "<Del>"
          )
        )
    end
  end, vim.api.nvim_create_namespace(__module_name__))

  ---@param reason                      string
  ---@return nil
  local function refresh(reason)
    if session ~= nil and session.internal then
      return
    end
    -- Cursor/text notifications for the same key must not replace its actual cause.
    if not queued or (reason ~= "move" and (reason ~= "change" or trigger == "move")) then
      trigger = reason
    end
    if queued then
      return
    end
    queued = true
    vim.schedule(function()
      queued = false
      if vim.v.exiting ~= vim.NIL then
        return
      end
      local context = Context.capture(trigger)
      backspace = false
      if context == nil then
        if session ~= nil then
          session:hide()
          session.signature:hide()
        end
        return
      end
      if vim.fn.pumvisible() == 1 and (session == nil or not session.menu.active) then
        return
      end
      if Context.enabled(context) then
        get_session():update(context)
      elseif session ~= nil then
        session:hide()
        session.signature:hide()
      end
    end)
  end

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function(event)
      attach(event.buf)
      refresh("enter")
    end,
  })
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = group,
    callback = function()
      if session ~= nil then
        session:before_input()
      end
      refresh("typing")
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = group,
    callback = function()
      refresh(backspace and "backspace" or "change")
    end,
  })
  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = group,
    callback = function()
      refresh(backspace and "backspace" or "move")
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(event)
      if event.buf == vim.api.nvim_get_current_buf() then
        refresh("change")
      end
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = group,
    callback = function()
      Keymap.bind_cmdline()
      if session ~= nil then
        session:hide()
        session.signature:hide()
      end
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineChanged", {
    group = group,
    callback = function()
      if cmdline_typing then
        cmdline_typing = false
        Cmdline.update()
      end
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      if session ~= nil then
        session:hide()
      end
      refresh("move")
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      vim.schedule(function()
        local mode = vim.api.nvim_get_mode().mode
        if session ~= nil and mode:sub(1, 1) ~= "i" and mode:sub(1, 1) ~= "s" and mode ~= "c" then
          session:hide()
          session.signature:hide()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    callback = function()
      if session ~= nil and not session.internal then
        session:hide()
        session.signature:hide()
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(event)
      Context.forget(event.buf)
      Keymap.forget(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = group,
    callback = function(event)
      if session ~= nil and session.context ~= nil and session.context.bufnr == event.buf then
        vim.schedule(function()
          if session ~= nil and session.context ~= nil and session.context.bufnr == event.buf then
            session:show()
          end
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd("CompleteChanged", {
    group = group,
    callback = function()
      if session ~= nil then
        session:on_complete_changed()
      end
    end,
  })
  vim.api.nvim_create_autocmd("CompleteDone", {
    group = group,
    callback = function()
      if session ~= nil then
        session:on_complete_done(vim.v.event.reason, vim.v.completed_item, backspace)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "VimResized" }, {
    group = group,
    callback = function(event)
      if session == nil then
        return
      end
      local winnr = vim.api.nvim_get_current_win()
      if event.event == "WinScrolled" and vim.v.event[tostring(winnr)] == nil then
        return
      end
      if event.event == "WinResized" then
        local layout_changed = false
        for _, changed_winnr in ipairs(vim.v.event.windows) do
          if
            vim.api.nvim_win_is_valid(changed_winnr)
            and (changed_winnr == winnr or vim.api.nvim_win_get_config(changed_winnr).relative == "")
          then
            -- Neighboring splits can move the source without changing its own size.
            layout_changed = true
            break
          end
        end
        if not layout_changed then
          return
        end
      end
      session:reposition()
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if session ~= nil then
        session:destroy()
      end
    end,
  })
  local mode = vim.api.nvim_get_mode().mode
  if mode:sub(1, 1) == "i" then
    attach(vim.api.nvim_get_current_buf())
    refresh("enter")
  elseif mode == "c" then
    Keymap.bind_cmdline()
  end
end

---@return boolean
function M.show()
  return vim.api.nvim_get_mode().mode == "c" and Cmdline.show() or get_session():show()
end

---@return boolean
function M.hide()
  if vim.api.nvim_get_mode().mode == "c" then
    return Cmdline.hide()
  end
  return session ~= nil and session:hide() or false
end

---@return boolean
function M.cancel()
  if vim.api.nvim_get_mode().mode == "c" then
    return Cmdline.hide(true)
  end
  return session ~= nil and session:hide(true) or false
end

---@param index                         ?integer
---@return boolean
function M.accept(index)
  if vim.api.nvim_get_mode().mode == "c" then
    return Cmdline.accept(index)
  end
  return session ~= nil and session:accept(index) or false
end

---@return boolean
function M.select_next()
  if vim.api.nvim_get_mode().mode == "c" then
    return Cmdline.select(1)
  end
  return session ~= nil and session:select(1) or false
end

---@return boolean
function M.select_prev()
  if vim.api.nvim_get_mode().mode == "c" then
    return Cmdline.select(-1)
  end
  return session ~= nil and session:select(-1) or false
end

---@return boolean
function M.is_menu_visible()
  if vim.api.nvim_get_mode().mode == "c" then
    return Cmdline.is_visible()
  end
  return session ~= nil and session:is_visible() or false
end

return M
