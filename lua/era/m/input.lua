---@see https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/input.lua

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.input" ---@type string

---@alias era.m.input.InputTypeEnum
---| "text"
---| "confirmation"

---@alias era.m.input.ConfirmCallback fun(): nil

---@alias era.m.input.CancelCallback fun(): nil

---@alias era.m.input.BeforeConfirmFn fun(text: string, confirm: era.m.input.ConfirmCallback, cancel: era.m.input.CancelCallback): nil

---@class era.m.input.IOptions
---@field public relative               ?"editor"|"cursor"|"win"
---@field public win                    ?integer
---@field public width                  ?integer
---@field public row                    ?integer
---@field public col                    ?integer
---@field public inputtype              ?era.m.input.InputTypeEnum
---
---@field public prompt                 ?string
---@field public default                ?string
---@field public completion             ?string
---@field public startinsert            ?boolean
---@field public before_confirm         ?era.m.input.BeforeConfirmFn
---@field public block_cancel           ?boolean

---@class era.m.input.IContext
---@field public completion             ?string

local contexts = {} ---@type table<integer, era.m.input.IContext>
local NSNR_CONFIRMATION = dot.var.nsnr.input_confirmation ---@type integer
local MAX_WIDTH = 120 ---@type integer

---@type string
local WIN_HIGHLIGHT = table.concat({
  "Cursor:m_in_current",
  "CursorColumn:m_in_current",
  "CursorLine:m_in_current",
  "CursorLineNr:m_in_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:m_in_normal",
  "SpecialKey:SpecialKey",
}, ",")

---@class era.m.input
local M = {}

---@param findstart                     integer
---@param base                          string
---@return integer|string[]
function M.complete(findstart, base)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local ctx = contexts[bufnr] ---@type era.m.input.IContext|nil
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

---@param opts                          ?era.m.input.IOptions
---@param on_confirm                    fun(value: string|nil): nil
---@return integer winnr
function M.open(opts, on_confirm)
  local parent_winnr = vim.api.nvim_get_current_win() ---@type integer
  local parent_row = vim.api.nvim_win_call(parent_winnr, vim.fn.winline) ---@type integer

  opts = opts or {} ---@type era.m.input.IOptions
  local inputtype = opts.inputtype or "text" ---@type era.m.input.InputTypeEnum
  local prompt = inputtype == "confirmation" and "? (y/N)  " or "" ---@type string
  local title = opts.prompt or "Input" ---@type string
  local description = {} ---@type string[]
  if inputtype == "confirmation" then
    local parts = vim.split(title, "\n", { plain = true })
    title = table.remove(parts, 1)
    description = parts
  end
  title = vim.trim(title):gsub(":$", "")
  local default = opts.default or "" ---@type string
  local max_width = math.min(MAX_WIDTH, math.max(1, vim.o.columns - 4)) ---@type integer
  local min_width = math.min(opts.width or 60, max_width) ---@type integer
  if inputtype == "confirmation" and vim.api.nvim_strwidth(title) + 6 > max_width then
    table.insert(description, 1, title)
    title = "Confirm"
  end
  local initial_text = inputtype == "confirmation" and prompt or default ---@type string
  assert(not initial_text:find("\n", 1, true), "Input default cannot contain newlines")
  local content_width = math.max(min_width, vim.api.nvim_strwidth(title) + 6, vim.api.nvim_strwidth(initial_text) + 5)
  for _, line in ipairs(description) do
    content_width = math.max(content_width, vim.api.nvim_strwidth(line) + 2)
  end
  local initial_width = math.min(content_width, max_width) ---@type integer
  local input_lnum = #description + 1 ---@type integer
  local height = math.min(input_lnum, 8, math.max(1, vim.o.lines - 4)) ---@type integer

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "prompt", { buf = bufnr })
  vim.api.nvim_set_option_value("completefunc", "v:lua.require'era.m.input'.complete", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", stl.filetype.UX_INPUT, { buf = bufnr })
  vim.api.nvim_set_option_value("omnifunc", "v:lua.require'era.m.input'.complete", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

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
    row = opts.row or (rows_below >= height + 2 and 1 or -height - 1)
    col = opts.col or 0
  end

  col = math.max(0, col)
  width = math.max(1, width)

  local zindex_source_winnr = relative_win or parent_winnr ---@type integer
  local zindex = dot.win.resolve_zindex(zindex_source_winnr) ---@type integer

  ---@type integer
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    anchor = "NW",
    border = "rounded",
    col = col,
    focusable = true,
    height = height,
    noautocmd = true,
    relative = relative,
    row = row,
    style = "minimal",
    title = string.format(" %s %s ", stl.icon.ui.Edit, title),
    title_pos = "center",
    width = width,
    win = relative_win,
    zindex = zindex,
  })

  vim.w[winnr].wintype = stl.e.WinTypeEnum.INPUT
  vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

  vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("relativenumber", false, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winblend", 0, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", WIN_HIGHLIGHT, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", #description > 0, { win = winnr, scope = "local" })

  contexts[bufnr] = { completion = opts.completion }

  local disposed = false ---@type boolean
  local focus_revoked = false ---@type boolean
  local focus_autocmd_id = nil ---@type integer|nil

  ---@return nil
  local function clear_focus_watch()
    if focus_autocmd_id ~= nil then
      pcall(vim.api.nvim_del_autocmd, focus_autocmd_id)
      focus_autocmd_id = nil
    end
  end

  ---@param text                        ?string
  local function dispose(text)
    if disposed then
      return
    end
    disposed = true
    contexts[bufnr] = nil
    clear_focus_watch()

    if vim.api.nvim_get_current_win() == winnr then
      vim.cmd("stopinsert")
    end

    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    vim.schedule(function()
      on_confirm(text)
    end)
  end

  local before_confirm = opts.before_confirm ---@type era.m.input.BeforeConfirmFn|nil
  local block_cancel = opts.block_cancel or false ---@type boolean
  local confirming = false ---@type boolean

  local action = {
    cancel = function()
      if block_cancel and confirming then
        return
      end
      dispose(nil)
    end,
    confirm = function()
      if disposed or confirming then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, input_lnum - 1, input_lnum, false) ---@type string[]
      local text = string.sub(lines[1] or "", #prompt + 1) ---@type string
      if before_confirm then
        confirming = true
        local confirm_cb = function()
          confirming = false
          dispose(text)
        end ---@type era.m.input.ConfirmCallback
        local cancel_cb = function()
          confirming = false
        end ---@type era.m.input.CancelCallback
        before_confirm(text, confirm_cb, cancel_cb)
      else
        dispose(text)
      end
    end,
    force_cancel = function()
      dispose(nil)
    end,
  }

  vim.fn.prompt_setprompt(bufnr, prompt)
  vim.fn.prompt_setcallback(bufnr, action.confirm)
  vim.fn.prompt_setinterrupt(bufnr, action.cancel)

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "x" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>" },
      desc = "input: quit",
      callback = action.cancel,
    },
    { modes = { "i", "n", "x" }, key = "<CR>", desc = "input: confirm", callback = action.confirm },
    { modes = { "n", "x" }, key = "o", desc = "input: noop", callback = stl.fn.noop },
    { modes = { "n", "x" }, key = "O", desc = "input: noop", callback = stl.fn.noop },
    { modes = { "n", "x" }, key = "q", desc = "input: force quit", callback = action.force_cancel },
  }

  if opts.inputtype == "confirmation" then
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "<Esc>",
      desc = "input: cancel (no)",
      callback = action.cancel,
    })
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "n",
      aliases = { "N" },
      desc = "input: cancel (no)",
      callback = action.cancel,
    })
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = "y",
      aliases = { "Y" },
      desc = "input: confirm (yes)",
      callback = function()
        dispose("y")
      end,
    })
  end
  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.api.nvim_set_current_win(winnr)
  local lines = vim.list_extend(description, { initial_text })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(winnr, { input_lnum, #initial_text })
  if prompt == "" then
    vim.api.nvim_win_set_height(winnr, 1)
  else
    vim.hl.range(bufnr, NSNR_CONFIRMATION, "SpecialKey", { input_lnum - 1, 0 }, { input_lnum - 1, #prompt }, {})
    height = math.min(vim.api.nvim_win_text_height(winnr, {}).all, 8, math.max(1, vim.o.lines - 4))
    vim.api.nvim_win_set_height(winnr, height)
    if relative == "cursor" and opts.row == nil then
      local rows_below = vim.api.nvim_win_get_height(parent_winnr) - parent_row
      local config = vim.api.nvim_win_get_config(winnr)
      local offset = rows_below >= height + 2 and 1 or -height - 1
      config.row = config.row + offset - row
      vim.api.nvim_win_set_config(winnr, config)
    end
  end

  if opts.startinsert then
    vim.cmd("startinsert")
  end

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buf = bufnr,
    callback = function()
      if disposed or not vim.api.nvim_win_is_valid(winnr) then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, input_lnum - 1, input_lnum, false) ---@type string[]
      local text = lines[1] or "" ---@type string
      local text_width = vim.api.nvim_strwidth(text) + 5 ---@type integer
      local new_width = math.min(math.max(initial_width, text_width), max_width) ---@type integer
      local current_cfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
      if current_cfg.width ~= new_width then
        vim.api.nvim_win_set_config(winnr, { width = new_width })
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buf = bufnr,
    callback = function()
      focus_revoked = true
      clear_focus_watch()
      vim.schedule(action.cancel)
    end,
  })

  focus_autocmd_id = vim.api.nvim_create_autocmd("WinEnter", {
    callback = function()
      if disposed or vim.api.nvim_get_current_win() == winnr then
        return
      end
      focus_revoked = true
      focus_autocmd_id = nil
      return true
    end,
  })

  vim.schedule(function()
    clear_focus_watch()
    if disposed then
      return
    end
    if focus_revoked then
      action.cancel()
      return
    end
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
    end
  end)

  return winnr
end

----------------------------------------------------------------------------------------------------

---@return nil
function M.dressing()
  local original_input = vim.ui.input
  stl.fn.observe({ dot.context.flight.dressing_input }, function()
    local flag = dot.context.flight.dressing_input:snapshot() ---@type boolean
    if flag then
      vim.ui.input = M.open
    else
      vim.ui.input = original_input
    end
  end, false)
end

return M
