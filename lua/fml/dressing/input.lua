local fn = require("eve.builtin.fn")
local ft = require("eve.constant.filetype")

---@class fml.dressing.input.IOptions
---@field public relative               ?string
---@field public row                    ?integer
---@field public col                    ?integer
---@field public width                  ?integer
---
---@field public prompt                 ?string
---@field public default                ?string
---@field public completion             ?string
---@field public highlight              ?fun(): string

---@class fml.dressing.input.IContext
---@field public opts                   fml.dressing.input.IOptions

local ctx = { opts = {} } ---@type fml.dressing.input.IContext
local enabled = false ---@type boolean
local original_input = vim.ui.input

---@class fml.dressing.input
local M = {}

---@return nil
function M.enable()
  vim.ui.input = M.input
  enabled = true
end

---@return nil
function M.disable()
  vim.ui.input = original_input
  enabled = false
end

---@return nil
function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

---@return boolean
function M.is_enabled()
  return enabled
end

---@param findstart                     integer
---@param base                          string
---@return integer|string[]
function M.complete(findstart, base)
  local completion = ctx.opts.completion
  if findstart == 1 then
    return 0
  end
  if not completion then
    return {}
  end
  local ok, results = pcall(vim.fn.getcompletion, base, completion)
  return ok and results or {}
end

---@param opts                          ?fml.dressing.input.IOptions
---@param on_confirm                    fun(value: string|nil): nil
---@return integer
function M.input(opts, on_confirm)
  local parent_win = vim.api.nvim_get_current_win() ---@type integer
  local parent_win_cfg = vim.api.nvim_win_get_config(parent_win)
  local parent_cursor = vim.api.nvim_win_get_cursor(parent_win)

  opts = opts or {} ---@type fml.dressing.input.IOptions
  local prompt = opts.prompt and vim.trim(opts.prompt):gsub(":$", "") or "Input" ---@type string
  local default = opts.default or "" ---@type string

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].completefunc = "v:lua.require'fml.dressing.input'.complete"
  vim.bo[bufnr].omnifunc = "v:lua.require'fml.dressing.input'.complete"
  vim.bo[bufnr].filetype = ft.UX_INPUT
  vim.bo[bufnr].swapfile = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { default })

  local winnr = vim.api.nvim_open_win(bufnr, true, {
    zindex = parent_win_cfg.zindex and parent_win_cfg.zindex + 1 or nil,
    relative = opts.relative or "cursor",
    anchor = "NW",
    focusable = true,
    row = opts.row or (parent_cursor[1] < 5 and 1 or -3),
    col = opts.col or 0,
    width = opts.width or 60,
    height = 1,
    title = "  " .. prompt .. " ",
    title_pos = "center",
    border = "rounded",
    style = "minimal",
    noautocmd = true,
  })
  vim.wo[winnr].cursorline = false
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.api.nvim_win_set_cursor(winnr, { 1, #default + 1 })

  ---@type fml.dressing.input.IContext
  ctx = {
    opts = {
      prompt = prompt,
      default = default,
      completion = opts.completion,
      highlight = opts.highlight,
    },
  }

  local disposed = false ---@type boolean
  local action = {
    cancel = function()
      if not disposed then
        disposed = true
        ctx.opts = {}
        vim.cmd.stopinsert()

        vim.api.nvim_win_close(winnr, true)
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(parent_win) then
            vim.api.nvim_set_current_win(parent_win)
          end
          on_confirm()
        end)
      end
    end,
    confirm = function()
      if not disposed then
        disposed = true
        ctx.opts = {}
        vim.cmd.stopinsert()

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
        local text = lines[1] or "" ---@type string

        vim.api.nvim_win_close(winnr, true)
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(parent_win) then
            vim.api.nvim_set_current_win(parent_win)
          end
          on_confirm(text)
        end)
      end
    end,
  }

  vim.fn.prompt_setprompt(bufnr, "")
  vim.fn.prompt_setcallback(bufnr, action.confirm)
  vim.fn.prompt_setinterrupt(bufnr, action.cancel)

  ---@type eve.t.IKeymap[]
  local keymaps = {
    { modes = { "n" }, key = "q", desc = "input: quit", callback = action.cancel },
    { modes = { "i", "n" }, key = "<cr>", desc = "input: confirm", callback = action.confirm },
  }
  fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  return winnr
end

return M
