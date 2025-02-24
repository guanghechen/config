local config = require("fml.dressing.image.config")

local size ---@type fml.dressing.image.terminal.Dim?
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("fml.dressing.image.terminal", { clear = true }),
  callback = function()
    size = nil
  end,
})

-- HACK: ghostty doesn't like it when sending images too fast,
-- after Neovim startup, so we delay the first image
local queue = {} ---@type string[]?
vim.defer_fn(function()
  if queue and #queue > 0 then
    io.stdout:write(table.concat(queue, ""))
  end
  queue = nil
end, 100)

---@class fml.dressing.image.terminal
local M = {}

function M.size()
  if size then
    return size
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
  ---@class fml.dressing.image.terminal.Dim
  size = {
    width = vim.o.columns * dw,
    height = vim.o.lines * dh,
    columns = vim.o.columns,
    rows = vim.o.lines,
    cell_width = dw,
    cell_height = dh,
    scale = dw / 8,
  }

  pcall(function()
    ---@type { row: number, col: number, xpixel: number, ypixel: number }
    local sz = ffi.new("winsize")
    if ffi.C.ioctl(1, TIOCGWINSZ, sz) ~= 0 or sz.col == 0 or sz.row == 0 then
      return
    end
    size = {
      width = sz.xpixel,
      height = sz.ypixel,
      columns = sz.col,
      rows = sz.row,
      cell_width = sz.xpixel / sz.col,
      cell_height = sz.ypixel / sz.row,
      -- try to guess dpi scale
      scale = math.max(1, sz.xpixel / sz.col / 8),
    }
  end)

  return size
end

---@param opts table<string, string|number>|{data?: string}
function M.request(opts)
  opts.q = opts.q or 2 -- silence all
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
  local env = config.resolve_env() ---@type fml.dressing.image.config.env
  if env.transform then
    data = env.transform(data)
  end
  M.write(data)
end

---@param pos {[1]: number, [2]: number}
function M.set_cursor(pos)
  M.write("\27[" .. pos[1] .. ";" .. (pos[2] + 1) .. "H")
end

function M.write(data)
  if queue then
    table.insert(queue, data)
  else
    io.stdout:write(data)
  end
end

return M
