---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/input.lua

---@alias fml.dressing.input.InputTypeEnum
---| "text"
---| "confirmation"

---@class fml.dressing.input.IOptions
---@field public relative               ?"editor"|"cursor"|"win"
---@field public win                    ?integer
---@field public width                  ?integer
---@field public row                    ?integer
---@field public col                    ?integer
---@field public inputtype              ?"text"|"confirmation"
---
---@field public prompt                 ?string
---@field public default                ?string
---@field public completion             ?string
---@field public startinsert            ?boolean

---@class fml.dressing.input.IContext
---@field public completion             ?string

local contexts = {} ---@type table<integer, fml.dressing.input.IContext>
local NSNR_DEFAULT_CONFIRMATION = dot.var.nsnr.input_confirmation ---@type integer
local MAX_WIDTH = 120 ---@type integer

---@type string
local WIN_HIGHLIGHT = table.concat({
  "Cursor:f_ui_current",
  "CursorColumn:f_ui_current",
  "CursorLine:f_ui_current",
  "CursorLineNr:f_ui_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:f_ui_normal",
  "SpecialKey:SpecialKey",
}, ",")

---@class fml.dressing.input
local M = {}

---@param findstart                     integer
---@param base                          string
---@return integer|string[]
function M.complete(findstart, base)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local ctx = contexts[bufnr] ---@type fml.dressing.input.IContext|nil
  local completion = ctx and ctx.completion or nil ---@type string|nil
  if findstart == 1 then
    if vim.api.nvim_buf_is_valid(bufnr) then
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false) ---@type string[]
      local text = lines[1] or "" ---@type string
      return #text:gsub("%S+$", "")
    end
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
  local parent_cursor = vim.api.nvim_win_get_cursor(parent_winnr) ---@type integer[]
  local parent_row = parent_cursor[1] ---@type integer

  opts = opts or {} ---@type fml.dressing.input.IOptions
  local inputtype = opts.inputtype or "text" ---@type fml.dressing.input.InputTypeEnum
  local prompt = inputtype == "confirmation" and "? (y/n)  " or "" ---@type string
  local title = opts.prompt and vim.trim(opts.prompt):gsub(":$", "") or "Input" ---@type string
  local default = opts.default or "" ---@type string
  local min_width = opts.width or 60 ---@type integer
  local initial_text = inputtype == "confirmation" and prompt or default ---@type string
  local initial_width = math.min(math.max(min_width, vim.api.nvim_strwidth(initial_text) + 5), MAX_WIDTH) ---@type integer

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "prompt"
  vim.bo[bufnr].completefunc = "v:lua.require'fml.dressing.input'.complete"
  vim.bo[bufnr].omnifunc = "v:lua.require'fml.dressing.input'.complete"
  vim.bo[bufnr].filetype = dot.filetype.UX_INPUT
  vim.bo[bufnr].swapfile = false

  local winblend = eve.context.theme.get_float_winblend() ---@type integer
  local relative = opts.relative or "cursor" ---@type "editor"|"cursor"|"win"
  local relative_win = opts.win ---@type integer|nil

  if relative == "win" then
    if relative_win == nil or not vim.api.nvim_win_is_valid(relative_win) then
      relative = "cursor"
      relative_win = nil
    end
  else
    relative_win = nil
  end

  local width = initial_width ---@type integer
  local row ---@type integer
  local col ---@type integer

  if relative == "editor" then
    row = opts.row or 3
    col = opts.col or math.floor((vim.o.columns - width) / 2)
  elseif relative == "win" then
    row = opts.row or 0
    col = opts.col or 0
  else
    local win_height = vim.api.nvim_win_get_height(parent_winnr) ---@type integer
    local rows_below = win_height - parent_row ---@type integer
    row = opts.row or (rows_below >= 3 and 1 or -2)
    col = opts.col or 0
  end

  col = math.max(0, col)
  width = math.max(1, width)

  local zindex_source_winnr = relative_win or parent_winnr ---@type integer
  local zindex = eve.win.resolve_zindex(zindex_source_winnr) ---@type integer

  ---@type integer
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    zindex = zindex,
    relative = relative,
    win = relative_win,
    anchor = "NW",
    row = row,
    col = col,
    width = width,
    height = 1,
    border = "rounded",
    style = "minimal",
    focusable = true,
    noautocmd = true,
    title = string.format(" %s %s ", dot.icon.ui.Edit, title),
    title_pos = "center",
  })

  eve.win.set_type(winnr, eve.win.Types.INPUT)
  vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

  vim.wo[winnr].cursorline = false
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = WIN_HIGHLIGHT

  contexts[bufnr] = { completion = opts.completion }

  local disposed = false ---@type boolean

  ---@param text                        ?string
  local function dispose(text)
    if disposed then
      return
    end
    disposed = true
    contexts[bufnr] = nil
    vim.cmd("stopinsert")

    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(parent_winnr) then
        vim.api.nvim_set_current_win(parent_winnr)
        pcall(vim.api.nvim_win_set_cursor, parent_winnr, parent_cursor)
      end
      on_confirm(text)
    end)
  end

  local action = {
    cancel = function()
      dispose(nil)
    end,
    confirm = function()
      if disposed then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
      local text = string.sub(lines[1] or "", #prompt + 1) ---@type string
      dispose(text)
    end,
  }

  vim.fn.prompt_setprompt(bufnr, prompt)
  vim.fn.prompt_setcallback(bufnr, action.confirm)
  vim.fn.prompt_setinterrupt(bufnr, action.cancel)

  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "x" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>" },
      desc = "input: quit",
      callback = action.cancel,
    },
    { modes = { "i", "n", "x" }, key = "<cr>", desc = "input: confirm", callback = action.confirm },
    { modes = { "n", "x" }, key = "q", desc = "input: quit", callback = action.cancel },
    { modes = { "n", "x" }, key = "o", desc = "input: noop", callback = ark.fn.noop },
    { modes = { "n", "x" }, key = "O", desc = "input: noop", callback = ark.fn.noop },
  }

  -- Add y/n/<Esc> keymaps for confirmation type inputs
  if opts.inputtype == "confirmation" then
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "<Esc>",
      desc = "input: cancel (no)",
      callback = action.cancel,
    })
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "y",
      desc = "input: confirm (yes)",
      callback = function()
        dispose("y")
      end,
    })
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "Y",
      desc = "input: confirm (yes)",
      callback = function()
        dispose("y")
      end,
    })
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "n",
      desc = "input: cancel (no)",
      callback = action.cancel,
    })
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "N",
      desc = "input: cancel (no)",
      callback = action.cancel,
    })
  end
  ark.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.api.nvim_set_current_win(winnr)
  if prompt == "" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { default })
    vim.api.nvim_win_set_cursor(winnr, { 1, #default })
  else
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { prompt })
    vim.api.nvim_win_set_cursor(winnr, { 1, #prompt })
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.hl.range(bufnr, NSNR_DEFAULT_CONFIRMATION, "SpecialKey", { 0, 0 }, { 0, #prompt }, {})
    end
  end

  if opts.startinsert then
    vim.cmd("startinsert")
  end

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = bufnr,
    callback = function()
      if disposed or not vim.api.nvim_win_is_valid(winnr) then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false) ---@type string[]
      local text = lines[1] or "" ---@type string
      local text_width = vim.api.nvim_strwidth(text) + 5 ---@type integer
      local new_width = math.min(math.max(min_width, text_width), MAX_WIDTH) ---@type integer
      local current_cfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
      if current_cfg.width ~= new_width then
        vim.api.nvim_win_set_config(winnr, { width = new_width })
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      vim.schedule(action.cancel)
    end,
  })

  vim.schedule(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
    end
  end)

  return winnr
end

local original_input = vim.ui.input
std.fn.observe({ eve.context.flight.dressing_input }, function()
  local flag = eve.context.flight.dressing_input:snapshot() ---@type boolean
  if flag then
    vim.ui.input = M.input
  else
    vim.ui.input = original_input
  end
end, false)

return M
