---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.winpicker" ---@type string

local winhighlight = table.concat({
  "FloatBorder:FloatBorder",
  "Normal:NormalFloat",
}, ",")

---@class dot.winpicker
---@field public char                   string
---@field public hint                   string[]
---@field public bufnr_hint             integer|nil
---@field public winnr_hint             integer|nil
---@field public winnr_target           integer|nil
local M = {}
M.__index = M

M.renderers = {} ---@type table<string, dot.winpicker>

---@param char                          string
---@return dot.winpicker
function M.new(char)
  if M.renderers[char] ~= nil then
    return M.renderers[char]
  end

  local hint = stl.winhint[char] ---@type string[]

  local self = setmetatable({}, M)
  self.char = char
  self.hint = hint
  self.bufnr_hint = nil
  self.winnr_hint = nil
  self.winnr_target = nil
  -- Each pick shows a renderer per window; a cached one reuses its hidden hint buffer instead of leaving another.
  M.renderers[char] = self
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return integer
function M:__create_buf_as_needed__()
  local bufnr_hint = self.bufnr_hint ---@type integer|nil
  if bufnr_hint == nil or not vim.api.nvim_buf_is_valid(bufnr_hint) then
    bufnr_hint = vim.api.nvim_create_buf(false, true) ---@type integer
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr_hint })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr_hint })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr_hint })
    vim.api.nvim_set_option_value("filetype", stl.filetype.WINPICKER_MASK, { buf = bufnr_hint })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr_hint })
    vim.api.nvim_buf_set_lines(bufnr_hint, 0, -1, true, self.hint)
    self.bufnr_hint = bufnr_hint
  end
  return bufnr_hint
end

---@param winnr                         integer
---@return integer
function M:show(winnr)
  local bufnr_hint = self:__create_buf_as_needed__() ---@type integer

  local width_target = vim.api.nvim_win_get_width(winnr) ---@type integer
  local height_target = vim.api.nvim_win_get_height(winnr) ---@type integer
  local width = 15 ---@type integer
  local height = #self.hint ---@type integer
  local row = math.floor((height_target - height) / 2) ---@type integer
  local col = math.floor((width_target - width) / 2) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg_hint = {
    zindex = dot.win.resolve_zindex(),
    relative = "win",
    win = winnr,
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    focusable = false,
    title = "",
  }

  local winnr_hint = self.winnr_hint ---@type integer|nil
  if winnr_hint == nil or not vim.api.nvim_win_is_valid(winnr_hint) then
    wincfg_hint.noautocmd = true
    winnr_hint = vim.api.nvim_open_win(bufnr_hint, false, wincfg_hint) ---@type integer
    self.winnr_hint = winnr_hint

    vim.w[winnr_hint].wintype = stl.e.WinTypeEnum.WINPICKER
    vim.w[winnr_hint][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("winblend", 0, { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("relativenumber", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("wrap", false, { win = winnr_hint, scope = "local" })
  else
    vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_win_set_config(winnr_hint, wincfg_hint)
    vim.api.nvim_win_set_buf(winnr_hint, bufnr_hint)
  end

  vim.api.nvim_set_option_value("cursorline", false, { win = winnr_hint, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr_hint, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", winhighlight, { win = winnr_hint, scope = "local" })
  return winnr_hint
end

---@return nil
function M:hide()
  local winnr_hint = self.winnr_hint ---@type integer|nil
  self.winnr_hint = nil

  if winnr_hint ~= nil and vim.api.nvim_win_is_valid(winnr_hint) then
    vim.api.nvim_win_close(winnr_hint, true)
  end
end

----------------------------------------------------------------------------------------------------

---Labels of the windows a pick offers, in the order the tab lists them.
local PICK_CHARS = {
  "F",
  "J",
  "D",
  "K",
  "S",
  "L",
  "A",
  ";",
  "C",
  "M",
  "R",
  "U",
  "E",
  "I",
  "W",
  "O",
  "Q",
  "P",
} ---@type string[]

---@return string|nil
local function get_user_input_char()
  local ok, c = pcall(vim.fn.getchar)

  if not ok then
    return
  end

  while type(c) ~= "number" do
    c = vim.fn.getchar()
  end

  return vim.fn.nr2char(c)
end

---@alias dot.winpicker.Filter fun(winnr: integer): boolean

---Picks a window of the current tab that `filter` accepts, besides `winnr_candidate`: the only one at once, or the one
---whose label the user types; with none, `split_as_needed` splits a scratch window off the first non-floating one.
---@param filter                        dot.winpicker.Filter
---@param winnr_candidate               integer|nil
---@param split_as_needed               boolean
---@return integer|nil
function M.pick(filter, winnr_candidate, split_as_needed)
  local winnr_original = vim.api.nvim_get_current_win() ---@type integer
  local tabnr_current = vim.api.nvim_get_current_tabpage() ---@type integer

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr_current) ---@type integer[]
  local N = 0 ---@type integer
  for i = 1, #winnrs, 1 do
    local winnr = winnrs[i] ---@type integer
    if winnr ~= winnr_candidate and filter(winnr) then
      N = N + 1 ---@type integer
      winnrs[N] = winnr
    end
  end

  if N < 1 then
    if split_as_needed then
      for _, winnr in ipairs(winnrs) do
        if not stl.nvim.win.is_float(winnr) then
          local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
          vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
          vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
          vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
          vim.api.nvim_set_option_value("filetype", "text", { buf = bufnr })
          vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

          vim.api.nvim_set_current_win(winnr)
          vim.cmd("vsplit")
          local winnr_new = vim.api.nvim_get_current_win() ---@type integer
          vim.api.nvim_win_set_buf(winnr_new, bufnr)
          return winnr_new
        end
      end
    end

    stl.reporter.warn({
      from = __module_name__,
      subject = "pick",
      message = "No windows left to pick after filtering",
    })
    return nil
  end

  if N == 1 then
    return winnrs[1]
  end

  local masks = {} ---@type table<integer, dot.winpicker>
  local winnr_target = nil ---@type integer|nil

  pcall(function()
    for i = 1, N, 1 do
      local winnr = winnrs[i] ---@type integer
      local char = PICK_CHARS[i] ---@type string
      local mask = M.new(char:lower()) ---@type dot.winpicker
      masks[winnr] = mask
    end

    for winnr, mask in pairs(masks) do
      mask:show(winnr)
    end

    vim.api.nvim__redraw({ flush = true })

    local char = get_user_input_char() ---@type string|nil
    if char ~= nil then
      char = char:lower() ---@type string
      for winnr, mask in pairs(masks) do
        if char == mask.char then
          winnr_target = winnr ---@type integer
          break
        end
      end
    end
  end)

  for _, mask in pairs(masks) do
    mask:hide()
  end
  vim.api.nvim__redraw({ flush = true })

  --- Refocus the original window if no window selected.
  if winnr_target == nil then
    vim.api.nvim_set_current_win(winnr_original)
  end

  return winnr_target
end

return M
