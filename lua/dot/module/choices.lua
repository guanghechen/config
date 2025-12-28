---@alias dot.module.choices.ItemKey
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

---@alias dot.module.choices.PositionEnum
---| "cursor"
---| "center"

---@class dot.module.choices.IItem
---@field public key                    dot.module.choices.ItemKey
---@field public text                   string

---@class dot.module.choices.IProps : vim.api.keyset.win_config
---@field public title                  string|nil
---@field public position               dot.module.choices.PositionEnum|nil
---@field public items                  dot.module.choices.IItem[]
---@field public default_key            dot.module.choices.ItemKey|nil
---@field public on_choice              fun(item: dot.module.choices.IItem|nil): nil

---@class dot.module.choices.IConfirmProps : vim.api.keyset.win_config
---@field public title                  string|nil
---@field public position               dot.module.choices.PositionEnum|nil
---@field public yes_text               string|nil
---@field public no_text                string|nil
---@field public default_yes            boolean|nil
---@field public on_choice              fun(confirmed: boolean): nil

local WIN_HIGHLIGHT = table.concat({
  "Cursor:m_ch_normal",
  "CursorColumn:m_ch_current",
  "CursorLine:m_ch_current",
  "CursorLineNr:m_ch_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:m_ch_normal",
}, ",")

---@class dot.module.choices
local M = {}

---@param props                         dot.module.choices.IProps
---@return integer
function M.open(props)
  local parent_winnr = vim.api.nvim_get_current_win() ---@type integer
  local items = props.items ---@type dot.module.choices.IItem[]
  local default_key = props.default_key ---@type dot.module.choices.ItemKey|nil
  local on_choice = props.on_choice ---@type fun(item: dot.module.choices.IItem|nil): nil

  local title = props.title and string.format(" %s ", props.title) or "" ---@type string
  local title_width = vim.api.nvim_strwidth(title) ---@type integer

  local default_index = 1 ---@type integer
  local content_width = 0 ---@type integer
  local lines = {} ---@type string[]

  local max_key_width = 0 ---@type integer
  for _, item in ipairs(items) do
    local key_width = #item.key ---@type integer
    if key_width > max_key_width then
      max_key_width = key_width
    end
  end

  for index, item in ipairs(items) do
    local padding = string.rep(" ", max_key_width - #item.key) ---@type string
    local line = string.format("  %s%s. %s", padding, item.key, item.text) ---@type string
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

  local nsnr = vim.api.nvim_create_namespace("ux:choices") ---@type integer
  for index, item in ipairs(items) do
    local row = index - 1 ---@type integer
    local key_start = 2 + max_key_width - #item.key ---@type integer
    local key_end = key_start + #item.key ---@type integer
    vim.hl.range(bufnr, nsnr, "m_ch_key", { row, key_start }, { row, key_end })
  end

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = "choices"
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].swapfile = false

  local winblend = dot.context.theme.get_float_winblend() ---@type integer
  local position = props.position or "center" ---@type dot.module.choices.PositionEnum

  local relative ---@type string
  local relative_win ---@type integer|nil
  local row ---@type integer
  local col ---@type integer

  if position == "cursor" then
    relative = "cursor"
    relative_win = nil
    local parent_cursor = vim.api.nvim_win_get_cursor(parent_winnr) ---@type integer[]
    local parent_row = parent_cursor[1] ---@type integer
    local win_height = vim.api.nvim_win_get_height(parent_winnr) ---@type integer
    local rows_below = win_height - parent_row ---@type integer
    row = rows_below >= #items + 2 and 1 or -#items - 2
    col = 0
  else
    relative = "editor"
    relative_win = nil
    row = math.floor((vim.o.lines - #items) / 2)
    col = math.floor((vim.o.columns - width) / 2)
  end

  if props.relative ~= nil then
    relative = props.relative
  end
  if props.win ~= nil then
    relative_win = props.win
  end
  if props.row ~= nil then
    row = props.row
  end
  if props.col ~= nil then
    col = props.col
  end

  col = math.max(0, col)

  local zindex_source_winnr = relative_win or parent_winnr ---@type integer
  local zindex = dot.win.resolve_zindex(zindex_source_winnr) ---@type integer

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
  }) ---@type integer

  dot.win.set_type(winnr, ark.vim.win.Types.SELECT)
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

  local sign_group = ark.var.sign.GROUP_CHOICES_CURRENT ---@type string
  local sign_nr = ark.var.sign.NR_CHOICES_CURRENT ---@type integer
  local sign_name = ark.var.sign.CHOICES_CURRENT ---@type string

  ---@param lnum                        integer
  ---@return nil
  local function update_sign(lnum)
    pcall(vim.fn.sign_unplace, sign_group, { id = sign_nr, buffer = bufnr })
    if lnum > 0 then
      pcall(vim.fn.sign_place, sign_nr, sign_group, sign_name, bufnr, { lnum = lnum, priority = 50 })
    end
  end

  update_sign(default_index)

  local disposed = false ---@type boolean

  ---@param item                        dot.module.choices.IItem|nil
  ---@return nil
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
      local item = items[index] ---@type dot.module.choices.IItem
      dispose(item)
    end,
  }

  ---@type ark.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "x" },
      key = "<Left>",
      aliases = { "<Right>", "h", "l", "0", "^", "$", "a", "A", "i", "I", "d", "o", "O", "x", "X", "u", "U", "v" },
      desc = "choices: noop",
      callback = ark.fn.noop,
    },
    {
      modes = { "i", "n", "x" },
      key = "<LeftMouse>",
      desc = "choices: move cursor",
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
      desc = "choices: cancel",
      callback = action.cancel,
    },
    {
      modes = { "i", "n", "x" },
      key = "<2-LeftMouse>",
      aliases = { "<CR>" },
      desc = "choices: confirm",
      callback = action.confirm,
    },
    {
      modes = { "n", "x" },
      key = "q",
      desc = "choices: quit",
      callback = action.cancel,
    },
  }

  for _, item in ipairs(items) do
    table.insert(keymaps, {
      modes = { "i", "n", "x" },
      key = item.key,
      desc = string.format("choices: select %s", item.key),
      callback = function()
        dispose(item)
      end,
    })
  end

  ark.vim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      vim.schedule(action.cancel)
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = bufnr,
    callback = function()
      if disposed then
        return
      end
      local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
      update_sign(cursor[1])
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

---@param props                         dot.module.choices.IConfirmProps
---@return integer
function M.confirm(props)
  local yes_text = props.yes_text or "Yes" ---@type string
  local no_text = props.no_text or "No" ---@type string
  local default_yes = props.default_yes ---@type boolean|nil
  local on_choice = props.on_choice ---@type fun(confirmed: boolean): nil

  return M.open({
    title = props.title,
    position = props.position,
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
