local config = require("fml.dressing.image.config")

-- HACK: ghostty doesn't like it when sending images too fast,
-- after Neovim startup, so we delay the first image
local queue = {} ---@type string[]?
vim.defer_fn(
  vim.schedule_wrap(function()
    for _, data in ipairs(queue or {}) do
      io.stdout:write(data)
    end
    queue = nil
  end),
  100
)

local size ---@type fml.dressing.image.terminal.Dim?
vim.api.nvim_create_autocmd("VimResized", {
  group = eve.std.nvim.augroup("fml.dressing.image.terminal"),
  callback = function()
    size = nil
  end,
})

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
    local winsize = ffi.new("winsize") ---@type { row: number, col: number, xpixel: number, ypixel: number }
    if ffi.C.ioctl(1, TIOCGWINSZ, winsize) == 0 and winsize.col ~= 0 and winsize.row ~= 0 then
      size = {
        width = winsize.xpixel,
        height = winsize.ypixel,
        columns = winsize.col,
        rows = winsize.row,
        cell_width = winsize.xpixel / winsize.col,
        cell_height = winsize.ypixel / winsize.row,
        scale = math.max(1, winsize.xpixel / winsize.col / 8), -- try to guess dpi scale
      }
    end
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
