---@class fml.dressing.input.IOptions
---@field public relative               ?"editor"|"cursor"
---@field public width                  ?integer
---
---@field public prompt                 ?string
---@field public default                ?string
---@field public completion             ?string
---@field public highlight              ?fun(): string

---@class fml.dressing.input.IContext
---@field public opts                   fml.dressing.input.IOptions

local ctx = { opts = {} } ---@type fml.dressing.input.IContext

---@type string
local WIN_HIGHLIGHT = table.concat({
  "Cursor:f_ui_current",
  "CursorColumn:f_ui_current",
  "CursorLine:f_ui_current",
  "CursorLineNr:f_ui_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:f_ui_normal",
}, ",")

---@class fml.dressing.input
local M = {}

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
  local parent_winnr = vim.api.nvim_get_current_win() ---@type integer
  local parent_win_cfg = vim.api.nvim_win_get_config(parent_winnr) ---@type vim.api.keyset.win_config
  local parent_row = unpack(vim.api.nvim_win_get_cursor(parent_winnr))

  opts = opts or {} ---@type fml.dressing.input.IOptions
  local prompt = opts.prompt and vim.trim(opts.prompt):gsub(":$", "") or "Input" ---@type string
  local default = opts.default or "" ---@type string

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].completefunc = "v:lua.require'fml.dressing.input'.complete"
  vim.bo[bufnr].omnifunc = "v:lua.require'fml.dressing.input'.complete"
  vim.bo[bufnr].filetype = eve.filetype.UX_INPUT
  vim.bo[bufnr].swapfile = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { default })

  local winblend = eve.context.theme.get_float_winblend() ---@type integer
  local relative = opts.relative or "cursor"
  local width = opts.width or 60 ---@type integer
  local row = relative == "editor" and 3 or (parent_row < 5 and 2 or 2) ---@type integer
  local col = relative == "editor" and math.floor((vim.o.columns - width) / 2) or 0 ---@type integer
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    zindex = parent_win_cfg.zindex and parent_win_cfg.zindex + 1 or nil,
    relative = relative,
    row = row,
    col = col,
    width = width,
    height = 1,
    border = "rounded",
    style = "minimal",
    focusable = true,
    noautocmd = true,
    title = string.format(" %s %s ", eve.icon.ui.Edit, prompt),
    title_pos = "center",
  })

  eve.win.set_type(winnr, eve.win.Types.INPUT)
  vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true

  vim.wo[winnr].cursorline = false
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = WIN_HIGHLIGHT
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
          if vim.api.nvim_win_is_valid(parent_winnr) then
            vim.api.nvim_set_current_win(parent_winnr)
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
          if vim.api.nvim_win_is_valid(parent_winnr) then
            vim.api.nvim_set_current_win(parent_winnr)
          end
          on_confirm(text)
        end)
      end
    end,
  }

  vim.fn.prompt_setprompt(bufnr, "")
  vim.fn.prompt_setcallback(bufnr, action.confirm)
  vim.fn.prompt_setinterrupt(bufnr, action.cancel)

  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>" },
      desc = "input: quit",
      callback = action.cancel,
    },
    { modes = { "i", "n" }, key = "<cr>", desc = "input: confirm", callback = action.confirm },
    { modes = { "n" }, key = "q", desc = "input: quit", callback = action.cancel },
    { modes = { "n" }, key = "o", desc = "input: noop", callback = std.fn.noop },
    { modes = { "n" }, key = "O", desc = "input: noop", callback = std.fn.noop },
  }
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  return winnr
end

local original_input = vim.ui.input
eve.fn.observe({ eve.context.flight.dressing_input }, function()
  local flag = eve.context.flight.dressing_input:snapshot() ---@type boolean
  if flag then
    vim.ui.input = M.input
  else
    vim.ui.input = original_input
  end
end, false)

return M
