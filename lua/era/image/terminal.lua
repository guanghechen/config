---@class era.image.terminal
local M = {}

---@class era.image.terminal.Dim
---@field public width                    integer
---@field public height                   integer
---@field public columns                  integer
---@field public rows                     integer
---@field public cell_width               number
---@field public cell_height              number
---@field public scale                    number

---@type era.image.terminal.Dim|nil
local _size = nil

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("era.image.terminal", { clear = true }),
  callback = function()
    _size = nil
  end,
})

---@return era.image.terminal.Dim
function M.size()
  if _size then
    return _size
  end

  local ffi = require("ffi")
  ffi.cdef([[
    typedef struct {
      unsigned short row;
      unsigned short col;
      unsigned short xpixel;
      unsigned short ypixel;
    } winsize;
    int ioctl(int, int, ...);
  ]])

  local TIOCGWINSZ = nil
  if vim.fn.has("linux") == 1 then
    TIOCGWINSZ = 0x5413
  elseif vim.fn.has("mac") == 1 or vim.fn.has("bsd") == 1 then
    TIOCGWINSZ = 0x40087468
  end

  local dw, dh = 9, 18
  ---@type era.image.terminal.Dim
  _size = {
    width = vim.o.columns * dw,
    height = vim.o.lines * dh,
    columns = vim.o.columns,
    rows = vim.o.lines,
    cell_width = dw,
    cell_height = dh,
    scale = dw / 8,
  }

  pcall(function()
    ---@type { row: integer, col: integer, xpixel: integer, ypixel: integer }
    local sz = ffi.new("winsize")
    if ffi.C.ioctl(1, TIOCGWINSZ, sz) ~= 0 or sz.col == 0 or sz.row == 0 then
      return
    end
    _size = {
      width = sz.xpixel,
      height = sz.ypixel,
      columns = sz.col,
      rows = sz.row,
      cell_width = sz.xpixel / sz.col,
      cell_height = sz.ypixel / sz.row,
      scale = math.max(1, sz.xpixel / sz.col / 8),
    }
  end)

  return _size
end

---@param opts                            table<string, string|number|nil>|{data?: string}
---@return nil
function M.request(opts)
  opts.q = opts.q ~= false and (opts.q or 2) or nil
  local msg = {} ---@type string[]
  for k, v in pairs(opts) do
    if k ~= "data" then
      table.insert(msg, string.format("%s=%s", k, v))
    end
  end
  msg = { table.concat(msg, ",") }
  if opts.data then
    msg[#msg + 1] = ";"
    msg[#msg + 1] = tostring(opts.data)
  end
  local data = "\27_G" .. table.concat(msg) .. "\27\\"
  M.write(data)
end

---@param pos                             {[1]: integer, [2]: integer}
---@return nil
function M.set_cursor(pos)
  M.write("\27[" .. pos[1] .. ";" .. (pos[2] + 1) .. "H")
end

---@param data                            string
---@return nil
function M.write(data)
  local state = require("era.image.state")
  data = state.env.transform and state.env.transform(data) or data
  if vim.api.nvim_ui_send then
    vim.api.nvim_ui_send(data)
  else
    io.stdout:write(data)
  end
end

return M
