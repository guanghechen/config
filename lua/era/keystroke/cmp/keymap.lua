---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.keymap" ---@type string

local Context = require("era.keystroke.cmp.context")
local Cmdline = require("era.keystroke.cmp.cmdline")
local M = {}
local bound = {} ---@type table<integer, boolean>
local cmdline_bound = false

---@param mode                          string
---@param key                           string
---@param bufnr                         ?integer
---@return table|nil
local function mapping_for(mode, key, bufnr)
  local wanted = vim.keycode(key)
  local mappings = bufnr and vim.api.nvim_buf_get_keymap(bufnr, mode) or vim.api.nvim_get_keymap(mode)
  for _, mapping in ipairs(mappings) do
    if vim.keycode(mapping.lhs) == wanted and not (mapping.desc or ""):match("^cmp:") then
      return mapping
    end
  end
  return nil
end

---@param mode                          string
---@param key                           string
---@param saved                         ?table
---@param mappings_only                 ?boolean
---@return nil
local function fallback(mode, key, saved, mappings_only)
  local mapping = saved or mapping_for(mode, key)
  if mapping == nil then
    if not mappings_only then
      vim.api.nvim_feedkeys(vim.keycode(key), "ni", false)
    end
    return
  end
  local value
  if type(mapping.callback) == "function" then
    value = mapping.callback()
    if mapping.expr ~= 1 then
      return
    end
  elseif mapping.expr == 1 then
    value = vim.api.nvim_eval(mapping.rhs)
  else
    value = mapping.rhs
  end
  if type(value) ~= "string" then
    return
  end
  value = value:gsub("<SID>", "<SNR>" .. tostring(mapping.sid) .. "_")
  if mapping.expr ~= 1 or mapping.replace_keycodes == 1 then
    value = vim.keycode(value)
  end
  vim.api.nvim_feedkeys(value, mapping.noremap == 1 and "ni" or "mi", false)
end

---@param mode                          string
---@param key                           string
---@param saved                         ?table
---@param get_session                   fun(): era.keystroke.cmp.Session
---@param action                        fun(session: era.keystroke.cmp.Session): boolean|nil
---@return nil
local function handle_key(mode, key, saved, get_session, action)
  local context = Context.capture()
  if context == nil or not Context.enabled(context) then
    fallback(mode, key, saved)
  elseif not action(get_session()) then
    fallback(mode, key, saved, key == "<C-j>" or key == "<C-k>")
  end
end

---@param bufnr                         integer
---@param get_session                   fun(): era.keystroke.cmp.Session
---@return nil
function M.bind_insert(bufnr, get_session)
  if bound[bufnr] then
    return
  end
  bound[bufnr] = true
  local actions = {
    ["<CR>"] = function(session)
      return session:accept()
    end,
    ["<Up>"] = function(session)
      return session:select(-1)
    end,
    ["<Down>"] = function(session)
      return session:select(1)
    end,
    ["<C-k>"] = function(session)
      return session:select(-1)
    end,
    ["<C-j>"] = function(session)
      return session:select(1)
    end,
    ["<C-h>"] = function(session)
      return session:hide()
    end,
    ["<C-e>"] = function(session)
      return session:hide(true)
    end,
    ["<C-y>"] = function(session)
      return vim.lsp.inline_completion.get() or session:accept()
    end,
    ["<C-l>"] = function(session)
      return vim.lsp.inline_completion.get() or session:accept()
    end,
    ["<C-b>"] = function(session)
      return session.documentation:scroll(-1)
    end,
    ["<C-f>"] = function(session)
      return session.documentation:scroll(1)
    end,
    ["<C-space>"] = function(session)
      if not session:is_visible() then
        return session:show()
      end
      if session.documentation:is_visible() then
        session:cancel_documentation()
        session.documentation:hide()
      else
        session:show_documentation(true)
      end
      return true
    end,
    ["<C-p>"] = function(session)
      if session.signature.winnr ~= nil then
        session.signature:hide()
        return true
      end
      local context = Context.capture("manual")
      if context ~= nil then
        session.signature:update(context, true)
        return true
      end
      return false
    end,
  }
  for _, direction in ipairs({ 1, -1 }) do
    actions[direction == 1 and "<Tab>" or "<S-Tab>"] = function(session)
      if session:select(direction) then
        return true
      end
      if vim.snippet.active({ direction = direction }) then
        vim.snippet.jump(direction)
        return true
      end
      if direction == 1 and vim.lsp.inline_completion.get() then
        return true
      end
      return false
    end
  end
  for index = 1, 9 do
    actions["<C-" .. index .. ">"] = function(session)
      session:accept(index)
      return true
    end
  end
  local keymaps = {} ---@type stl.t.IKeymap[]
  for key, action in pairs(actions) do
    for _, mode in ipairs({ "i", "s" }) do
      local saved = mapping_for(mode, key, bufnr)
      keymaps[#keymaps + 1] = {
        modes = { mode },
        key = key,
        desc = "cmp: " .. key,
        callback = function()
          handle_key(mode, key, saved, get_session, action)
        end,
      }
    end
  end
  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, silent = true, noremap = true })
end

---@return nil
function M.bind_cmdline()
  if cmdline_bound then
    return
  end
  cmdline_bound = true
  local actions = {
    ["<Tab>"] = function()
      return Cmdline.tab(1)
    end,
    ["<S-Tab>"] = function()
      return Cmdline.tab(-1)
    end,
    ["<Up>"] = function()
      return Cmdline.select(-1)
    end,
    ["<Down>"] = function()
      return Cmdline.select(1)
    end,
    ["<C-k>"] = function()
      return Cmdline.select(-1)
    end,
    ["<C-j>"] = function()
      return Cmdline.select(1)
    end,
    ["<C-p>"] = function()
      return Cmdline.select(-1)
    end,
    ["<C-n>"] = function()
      return Cmdline.select(1)
    end,
    ["<C-y>"] = Cmdline.accept,
    ["<C-e>"] = function()
      return Cmdline.hide(true)
    end,
    ["<C-space>"] = Cmdline.show,
    ["<End>"] = function()
      Cmdline.hide()
      return false
    end,
  }
  local keymaps = {} ---@type stl.t.IKeymap[]
  for key, action in pairs(actions) do
    local saved = mapping_for("c", key)
    keymaps[#keymaps + 1] = {
      modes = { "c" },
      key = key,
      desc = "cmp: cmdline " .. key,
      callback = function()
        if not Cmdline.enabled() then
          fallback("c", key, saved)
        elseif not action() then
          fallback("c", key, saved, key == "<C-j>" or key == "<C-k>")
        end
      end,
    }
  end
  stl.nvim.fn.bindkeys(keymaps, { silent = false, noremap = true })
end

---@param bufnr                         integer
---@return nil
function M.forget(bufnr)
  bound[bufnr] = nil
end

return M
