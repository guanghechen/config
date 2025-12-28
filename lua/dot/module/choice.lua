---@alias dot.module.choice.ItemKey
---| "1"
---| "2"
---| "3"
---| "4"
---| "5"
---| "6"
---| "7"
---| "8"
---| "9"
---| "y"
---| "n"

---@alias dot.module.choice.RelativeEnum
---| "editor"
---| "cursor"
---| "win"

---@class dot.module.choice.IItem
---@field public key                    dot.module.choice.ItemKey
---@field public text                   string

---@class dot.module.choice.IProps
---@field public title                  string|nil
---@field public relative               dot.module.choice.RelativeEnum|nil
---@field public win                    integer|nil
---@field public row                    integer|nil
---@field public col                    integer|nil
---@field public items                  dot.module.choice.IItem[]
---@field public default_key            dot.module.choice.ItemKey|nil
---@field public on_choice              fun(item: dot.module.choice.IItem|nil): nil

---@class dot.module.choice.IConfirmProps
---@field public title                  string|nil
---@field public relative               dot.module.choice.RelativeEnum|nil
---@field public win                    integer|nil
---@field public row                    integer|nil
---@field public col                    integer|nil
---@field public yes_text               string|nil
---@field public no_text                string|nil
---@field public default_yes            boolean|nil
---@field public on_choice              fun(confirmed: boolean): nil

---@type string
local WIN_HIGHLIGHT = table.concat({
  "Cursor:m_ch_current",
  "CursorColumn:m_ch_current",
  "CursorLine:m_ch_current",
  "CursorLineNr:m_ch_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:m_ch_normal",
}, ",")

---@class dot.module.choice
local M = {}

---@param props                         dot.module.choice.IProps
---@return integer winnr
function M.open(props)
  local parent_winnr = vim.api.nvim_get_current_win() ---@type integer
  local items = props.items ---@type dot.module.choice.IItem[]
  local default_key = props.default_key ---@type dot.module.choice.ItemKey|nil
  local on_choice = props.on_choice ---@type fun(item: dot.module.choice.IItem|nil): nil

  local title = props.title and string.format(" %s ", props.title) or "" ---@type string
  local title_width = vim.api.nvim_strwidth(title) ---@type integer

  local default_index = 1 ---@type integer
  local content_width = 0 ---@type integer
  local lines = {} ---@type string[]

  for index, item in ipairs(items) do
    local line = string.format("  %s.  %s", item.key, item.text) ---@type string
    lines[index] = line
    if default_key == item.key then
      default_index = index
    end
    local w = vim.api.nvim_strwidth(line) ---@type integer
    content_width = content_width < w and w or content_width
  end

  local width = math.max(content_width + 4, title_width + 2) ---@type integer

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local nsnr = vim.api.nvim_create_namespace("ux:choice") ---@type integer
  for index, item in ipairs(items) do
    local row = index - 1 ---@type integer
    local key_start = 2 ---@type integer
    local key_end = key_start + #item.key ---@type integer
    vim.hl.range(bufnr, nsnr, "m_ch_key", { row, key_start }, { row, key_end })
  end

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = ark.filetype.SELECT
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].swapfile = false

  local winblend = dot.context.theme.get_float_winblend() ---@type integer
  local relative = props.relative or "editor" ---@type dot.module.choice.RelativeEnum
  local relative_win = props.win ---@type integer|nil

  if relative == "win" then
    if relative_win == nil or not vim.api.nvim_win_is_valid(relative_win) then
      relative = "editor"
      relative_win = nil
    end
  else
    relative_win = nil
  end

  local row ---@type integer
  local col ---@type integer

  if relative == "editor" then
    row = props.row or math.floor((vim.o.lines - #items) / 2)
    col = props.col or math.floor((vim.o.columns - width) / 2)
  elseif relative == "win" then
    row = props.row or 0
    col = props.col or 0
  else
    local parent_cursor = vim.api.nvim_win_get_cursor(parent_winnr) ---@type integer[]
    local parent_row = parent_cursor[1] ---@type integer
    local win_height = vim.api.nvim_win_get_height(parent_winnr) ---@type integer
    local rows_below = win_height - parent_row ---@type integer
    row = props.row or (rows_below >= #items + 2 and 1 or -#items - 2)
    col = props.col or 0
  end

  col = math.max(0, col)

  local zindex_source_winnr = relative_win or parent_winnr ---@type integer
  local zindex = dot.win.resolve_zindex(zindex_source_winnr) ---@type integer

  ---@type integer
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    anchor = "NW",
    border = "rounded",
    col = col,
    focusable = true,
    height = #items,
    noautocmd = true,
    relative = relative,
    row = row,
    style = "minimal",
    title = title,
    title_pos = "center",
    width = width,
    win = relative_win,
    zindex = zindex,
  })

  dot.win.set_type(winnr, dot.win.Types.SELECT)
  vim.w[winnr][ark.var.N_WINLINE_DISABLED] = true

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = WIN_HIGHLIGHT
  vim.wo[winnr].wrap = false

  vim.api.nvim_win_set_cursor(winnr, { default_index, 0 })

  local disposed = false ---@type boolean

  ---@param item                        dot.module.choice.IItem|nil
  local function dispose(item)
    if disposed then
      return
    end
    disposed = true

    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    vim.schedule(function()
      if vim.api.nvim_win_is_valid(parent_winnr) then
        vim.api.nvim_set_current_win(parent_winnr)
      end
      on_choice(item)
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
      local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
      local index = cursor[1] ---@type integer
      local item = items[index] ---@type dot.module.choice.IItem
      dispose(item)
    end,
  }

  ---@type ark.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "x" },
      key = "<Left>",
      aliases = { "<Right>", "h", "l", "0", "^", "$", "a", "A", "i", "I", "d", "o", "O", "x", "X", "u", "U", "v" },
      desc = "choice: noop",
      callback = ark.fn.noop,
    },
    {
      modes = { "i", "n", "x" },
      key = "<LeftMouse>",
      desc = "choice: move cursor",
      callback = function()
        local current_winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == current_winnr then
          local cursor = vim.fn.getmousepos()
          pcall(vim.api.nvim_win_set_cursor, winnr, { cursor.line, 0 })
        end
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>", "<Esc>" },
      desc = "choice: cancel",
      callback = action.cancel,
    },
    {
      modes = { "i", "n", "x" },
      key = "<2-LeftMouse>",
      aliases = { "<CR>" },
      desc = "choice: confirm",
      callback = action.confirm,
    },
    {
      modes = { "n", "x" },
      key = "q",
      desc = "choice: quit",
      callback = action.cancel,
    },
  }

  for _, item in ipairs(items) do
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = item.key,
      desc = string.format("choice: select %s", item.key),
      callback = function()
        dispose(item)
      end,
    })
  end

  ark.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      vim.schedule(action.cancel)
    end,
  })

  vim.schedule(function()
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
    end
  end)

  return winnr
end

---@param props                         dot.module.choice.IConfirmProps
---@return integer winnr
function M.confirm(props)
  local yes_text = props.yes_text or "Yes" ---@type string
  local no_text = props.no_text or "No" ---@type string
  local default_yes = props.default_yes ---@type boolean|nil
  local on_choice = props.on_choice ---@type fun(confirmed: boolean): nil

  return M.open({
    title = props.title,
    relative = props.relative,
    win = props.win,
    row = props.row,
    col = props.col,
    items = {
      { key = "y", text = yes_text },
      { key = "n", text = no_text },
    },
    default_key = default_yes and "y" or "n",
    on_choice = function(item)
      on_choice(item ~= nil and item.key == "y")
    end,
  })
end

return M
