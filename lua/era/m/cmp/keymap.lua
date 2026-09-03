---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.keymap" ---@type string

local M = {}
local insert_fallbacks = {} ---@type table<integer, table<string, table>>
local insert_owners = {} ---@type table<integer, table<string, function>>
local cmdline_fallbacks = {} ---@type table<string, table>
local cmdline_actions = {
  accept = function()
    return false
  end,
  cancel = function()
    return false
  end,
  move = function()
    return false
  end,
  show = function()
    return false
  end,
} ---@type { accept: fun(index?: integer): boolean, cancel: fun(): boolean, move: fun(direction: -1|1): boolean, show: fun(direction: -1|1): boolean }
local actions = {
  accept = function()
    return false
  end,
  backspace = function() end,
  cancel = function()
    return false
  end,
  move = function()
    return false
  end,
  signature = function()
    return false
  end,
  show = function() end,
  visible = function()
    return false
  end,
} ---@type { accept: fun(bufnr: integer, index?: integer): boolean, backspace: fun(bufnr: integer): nil, cancel: fun(bufnr: integer): boolean, move: fun(bufnr: integer, direction: -1|1): boolean, signature: fun(bufnr: integer): boolean, show: fun(): nil, visible: fun(bufnr: integer): boolean }

local insert_keys = {
  "<CR>",
  "<Tab>",
  "<S-Tab>",
  "<BS>",
  "<C-y>",
  "<C-l>",
  "<Up>",
  "<C-k>",
  "<Down>",
  "<C-j>",
  "<C-h>",
  "<C-e>",
  "<C-b>",
  "<C-f>",
  "<C-space>",
  "<C-p>",
}
for index = 1, 9 do
  insert_keys[#insert_keys + 1] = "<C-" .. index .. ">"
end

local function feed(keys, mode)
  vim.api.nvim_feedkeys(vim.keycode(keys), mode or "ni", false)
end

---@param mode                          string
---@param key                           string
---@return table
local function capture(mode, key)
  return vim.fn.maparg(key, mode, false, true) or {}
end

---@param mapping                       table
---@param key                           string
local function fallback(mapping, key)
  if vim.tbl_isempty(mapping) then
    feed(key)
    return
  end

  local result
  if type(mapping.callback) == "function" then
    result = mapping.callback()
  elseif type(mapping.rhs) == "string" and mapping.rhs ~= "" then
    if mapping.expr == 1 then
      local ok, evaluated = pcall(vim.api.nvim_eval, mapping.rhs)
      if ok then
        result = evaluated
      else
        feed(key)
      end
    else
      feed(mapping.rhs, mapping.noremap == 1 and "ni" or "mi")
    end
  end
  if mapping.expr == 1 and type(result) == "string" then
    feed(result, mapping.noremap == 1 and "ni" or "mi")
  end
end

---@param mapping                       table
local function restore(mapping)
  if mapping.buffer ~= 1 then
    return
  end
  vim.fn.mapset("i", false, mapping)
end

---@param value                         { accept: fun(bufnr: integer, index?: integer): boolean, backspace: fun(bufnr: integer): nil, cancel: fun(bufnr: integer): boolean, move: fun(bufnr: integer, direction: -1|1): boolean, signature: fun(bufnr: integer): boolean, show: fun(): nil, visible: fun(bufnr: integer): boolean }
function M.set_actions(value)
  actions = value
end

---@param value                         { accept: fun(index?: integer): boolean, cancel: fun(): boolean, move: fun(direction: -1|1): boolean, show: fun(direction: -1|1): boolean }
function M.set_cmdline_actions(value)
  cmdline_actions = value
end

---@param bufnr                         integer
---@return nil
function M.bind(bufnr)
  if vim.b[bufnr].era_cmp_keymaps then
    return
  end
  local saved = {} ---@type table<string, table>
  vim.api.nvim_buf_call(bufnr, function()
    for _, key in ipairs(insert_keys) do
      saved[key] = capture("i", key)
    end
  end)
  insert_fallbacks[bufnr] = saved
  vim.b[bufnr].era_cmp_keymaps = true

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i" },
      key = "<CR>",
      callback = function()
        if not actions.accept(bufnr) then
          fallback(saved["<CR>"], "<CR>")
        end
      end,
      desc = "completion: accept or newline",
    },
    {
      modes = { "i" },
      key = "<Tab>",
      callback = function()
        if actions.move(bufnr, 1) then
          return
        elseif vim.snippet.active({ direction = 1 }) then
          vim.snippet.jump(1)
        elseif not vim.lsp.inline_completion.get() then
          fallback(saved["<Tab>"], "<Tab>")
        end
      end,
      desc = "completion: next",
    },
    {
      modes = { "i" },
      key = "<S-Tab>",
      callback = function()
        if actions.move(bufnr, -1) then
          return
        elseif vim.snippet.active({ direction = -1 }) then
          vim.snippet.jump(-1)
        else
          fallback(saved["<S-Tab>"], "<S-Tab>")
        end
      end,
      desc = "completion: previous",
    },
    {
      modes = { "i" },
      key = "<BS>",
      callback = function()
        actions.backspace(bufnr)
        fallback(saved["<BS>"], "<BS>")
      end,
      desc = "completion: cancel and delete",
    },
    {
      modes = { "i" },
      key = "<C-y>",
      callback = function()
        if not vim.lsp.inline_completion.get() and not actions.accept(bufnr) then
          fallback(saved["<C-y>"], "<C-y>")
        end
      end,
      desc = "completion: accept",
    },
    {
      modes = { "i" },
      key = "<C-l>",
      callback = function()
        if not vim.lsp.inline_completion.get() and not actions.accept(bufnr) then
          fallback(saved["<C-l>"], "<C-l>")
        end
      end,
      desc = "completion: accept",
    },
    {
      modes = { "i" },
      key = "<Up>",
      callback = function()
        if not actions.move(bufnr, -1) then
          fallback(saved["<Up>"], "<Up>")
        end
      end,
      desc = "completion: previous item",
    },
    {
      modes = { "i" },
      key = "<C-k>",
      callback = function()
        if not actions.move(bufnr, -1) then
          fallback(saved["<C-k>"], "<C-k>")
        end
      end,
      desc = "completion: previous item",
    },
    {
      modes = { "i" },
      key = "<Down>",
      callback = function()
        if not actions.move(bufnr, 1) then
          fallback(saved["<Down>"], "<Down>")
        end
      end,
      desc = "completion: next item",
    },
    {
      modes = { "i" },
      key = "<C-j>",
      callback = function()
        if not actions.move(bufnr, 1) then
          fallback(saved["<C-j>"], "<C-j>")
        end
      end,
      desc = "completion: next item",
    },
    {
      modes = { "i" },
      key = "<C-h>",
      callback = function()
        if not actions.cancel(bufnr) then
          fallback(saved["<C-h>"], "<C-h>")
        end
      end,
      desc = "completion: hide",
    },
    {
      modes = { "i" },
      key = "<C-e>",
      callback = function()
        if not actions.cancel(bufnr) then
          fallback(saved["<C-e>"], "<C-e>")
        end
      end,
      desc = "completion: cancel",
    },
    {
      modes = { "i" },
      key = "<C-b>",
      callback = function()
        if not actions.visible(bufnr) or not require("era.m.ui_attach.popupmenu").scroll_documentation(-1) then
          fallback(saved["<C-b>"], "<C-b>")
        end
      end,
      desc = "completion: scroll documentation up",
    },
    {
      modes = { "i" },
      key = "<C-f>",
      callback = function()
        if not actions.visible(bufnr) or not require("era.m.ui_attach.popupmenu").scroll_documentation(1) then
          fallback(saved["<C-f>"], "<C-f>")
        end
      end,
      desc = "completion: scroll documentation down",
    },
    {
      modes = { "i" },
      key = "<C-space>",
      callback = function()
        if not actions.visible(bufnr) or not require("era.m.ui_attach.popupmenu").toggle_documentation() then
          actions.show()
        end
      end,
      desc = "completion: show or toggle documentation",
    },
    {
      modes = { "i" },
      key = "<C-p>",
      callback = function()
        if not actions.signature(bufnr) then
          fallback(saved["<C-p>"], "<C-p>")
        end
      end,
      desc = "completion: signature help",
    },
  }

  for index = 1, 9 do
    local item_index = index ---@type integer
    keymaps[#keymaps + 1] = {
      modes = { "i" },
      key = "<C-" .. item_index .. ">",
      callback = function()
        actions.accept(bufnr, item_index)
      end,
      desc = "completion: accept item " .. item_index,
    }
  end

  local owners = {} ---@type table<string, function>
  for _, item in ipairs(keymaps) do
    local callback = item.callback
    if type(callback) == "function" then
      owners[item.key] = callback
    end
  end
  insert_owners[bufnr] = owners
  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

function M.bind_cmdline()
  for _, key in ipairs({ "<Tab>", "<S-Tab>", "<Up>", "<C-k>", "<Down>", "<C-j>", "<C-y>", "<C-e>" }) do
    cmdline_fallbacks[key] = capture("c", key)
  end
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "c" },
      key = "<Tab>",
      callback = function()
        if not cmdline_actions.show(1) then
          fallback(cmdline_fallbacks["<Tab>"], "<Tab>")
        end
      end,
      desc = "completion: next cmdline item",
    },
    {
      modes = { "c" },
      key = "<S-Tab>",
      callback = function()
        if not cmdline_actions.show(-1) then
          fallback(cmdline_fallbacks["<S-Tab>"], "<S-Tab>")
        end
      end,
      desc = "completion: previous cmdline item",
    },
    {
      modes = { "c" },
      key = "<Up>",
      callback = function()
        if not cmdline_actions.move(-1) then
          fallback(cmdline_fallbacks["<Up>"], "<Up>")
        end
      end,
      desc = "completion: previous cmdline item",
    },
    {
      modes = { "c" },
      key = "<C-k>",
      callback = function()
        if not cmdline_actions.move(-1) then
          fallback(cmdline_fallbacks["<C-k>"], "<C-k>")
        end
      end,
      desc = "completion: previous cmdline item",
    },
    {
      modes = { "c" },
      key = "<Down>",
      callback = function()
        if not cmdline_actions.move(1) then
          fallback(cmdline_fallbacks["<Down>"], "<Down>")
        end
      end,
      desc = "completion: next cmdline item",
    },
    {
      modes = { "c" },
      key = "<C-j>",
      callback = function()
        if not cmdline_actions.move(1) then
          fallback(cmdline_fallbacks["<C-j>"], "<C-j>")
        end
      end,
      desc = "completion: next cmdline item",
    },
    {
      modes = { "c" },
      key = "<C-y>",
      callback = function()
        if not cmdline_actions.accept() then
          fallback(cmdline_fallbacks["<C-y>"], "<C-y>")
        end
      end,
      desc = "completion: accept cmdline item",
    },
    {
      modes = { "c" },
      key = "<C-e>",
      callback = function()
        if not cmdline_actions.cancel() then
          fallback(cmdline_fallbacks["<C-e>"], "<C-e>")
        end
      end,
      desc = "completion: cancel cmdline item",
    },
  }
  stl.nvim.fn.bindkeys(keymaps, { noremap = true, silent = true })
end

---@param bufnr                         integer
function M.unbind(bufnr)
  if not vim.b[bufnr].era_cmp_keymaps then
    return
  end
  vim.b[bufnr].era_cmp_keymaps = nil
  local saved = insert_fallbacks[bufnr] or {}
  local owners = insert_owners[bufnr] or {}
  insert_fallbacks[bufnr] = nil
  insert_owners[bufnr] = nil
  vim.api.nvim_buf_call(bufnr, function()
    for _, key in ipairs(insert_keys) do
      local current = capture("i", key)
      if current.callback == owners[key] then
        pcall(vim.keymap.del, "i", key, { buffer = bufnr })
        restore(saved[key] or {})
      end
    end
  end)
end

---@param bufnr                         integer
---@return boolean
function M.release(bufnr)
  local owned = insert_fallbacks[bufnr] ~= nil or insert_owners[bufnr] ~= nil
  insert_fallbacks[bufnr] = nil
  insert_owners[bufnr] = nil
  return owned
end

return M
