local env = require("era.m.image.env")

---@class era.m.image.state.data
---@field public resolve                 ?fun(file: string, src: string): string|nil
---@field public wo                      ?table<string, any>
local data = {
  tmpdir = dot.path.join(vim.fn.stdpath("cache"), "image/"),
  -- Milliseconds a conversion step may run before it is killed, so a converter that hangs (a stalled mount, an
  -- endless download) cannot keep one of the few conversion slots for good.
  convert_timeout = 30000,
  wo = {
    wrap = false,
    number = false,
    relativenumber = false,
    cursorcolumn = false,
    signcolumn = "no",
    foldcolumn = "0",
    list = false,
    spell = false,
    statuscolumn = "",
  },
  doc = {
    enabled = true,
    max_width = 80,
    max_height = 40,
    ---@param lang                      string
    ---@param type                      era.m.image.Type
    ---@return boolean
    ---@diagnostic disable-next-line: unused-local
    conceal = function(lang, type)
      return type == "math"
    end,
  },
  extnames = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".bmp",
    ".webp",
    ".tiff",
    ".heic",
    ".avif",
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",
    ".webm",
    ".pdf",
  },
  icons = {
    math = "󰪚 ",
    chart = "󰄧 ",
    image = " ",
  },
  img_dirs = { "img", "images", "assets", "static", "public", "media", "attachments" },
  math = {
    enabled = true,
    latex = {
      font_size = "normalsize",
      packages = { "amsmath", "amssymb", "amsfonts", "amscd", "mathtools", "mathpazo" },
      tpl = [[
        \documentclass[preview,border=0pt,varwidth,12pt]{standalone}
        \usepackage{${packages}}
        \begin{document}
        ${header}
        { \${font_size} \selectfont
        ${content}}
        \end{document}]],
    },
  },
}

local SUPPORTED_EXTNAME_SET = stl.table.to_string_set(data.extnames) ---@type table<string, boolean>

---@alias era.m.image.Size         {width: integer, height: integer}

---@alias era.m.image.Pos          {[1]: integer, [2]: integer}

---@alias era.m.image.Loc          era.m.image.Pos|era.m.image.Size

---@alias era.m.image.Type         "image"|"math"|"chart"

---@class era.m.image.Info
---@field public format                  string
---@field public size                    era.m.image.Size
---@field public dpi                     era.m.image.Size

---Pixel sizes by file, with the file version they were read from.
---@type table<string, {version: string, size: era.m.image.Size}>
local dims = {}

---@class era.m.image.state
---@field public data                    era.m.image.state.data
---@field public did_setup               boolean
---@field public env                     era.m.image.env
local M = {
  data = data,
  did_setup = false,
  env = env,
}

---@param file                           string
---@return era.m.image.Size
function M.dim(file)
  file = dot.path.normalize(file)
  -- A PNG rewritten in place keeps its path, so its size is reused only for the same file version.
  local version = M.version(file)
  local cached = dims[file]
  if cached and cached.version == version then
    return cached.size
  end
  local fd = assert(io.open(file, "rb"), "Failed to open file: " .. file)
  local header = fd:read(24) ---@type string
  fd:close()
  assert(header:sub(1, 8) == "\137PNG\r\n\26\n", "Not a valid PNG file: " .. file)
  local width = header:byte(17) * 16777216 + header:byte(18) * 65536 + header:byte(19) * 256 + header:byte(20)
  local height = header:byte(21) * 16777216 + header:byte(22) * 65536 + header:byte(23) * 256 + header:byte(24)
  local size = { width = width, height = height } ---@type era.m.image.Size
  dims[file] = { version = version, size = size }
  return size
end

---@param size                           era.m.image.Size
---@return era.m.image.Size
function M.pixels_to_cells(size)
  local terminal = require("era.m.image.terminal")
  local terminal_size = terminal.size()
  return M.norm({
    width = size.width / terminal_size.cell_width,
    height = size.height / terminal_size.cell_height,
  })
end

---@param size                           era.m.image.Size
---@return era.m.image.Size
function M.norm(size)
  return {
    width = math.max(1, math.ceil(size.width)),
    height = math.max(1, math.ceil(size.height)),
  }
end

---@param file                           string
---@param cells                          era.m.image.Size
---@param opts                           ?{ full?: boolean, info?: era.m.image.Info }
---@return era.m.image.Size
function M.fit(file, cells, opts)
  opts = opts or {}
  local terminal = require("era.m.image.terminal")
  local img_pixels ---@type era.m.image.Size
  if opts.info then
    local terminal_size = terminal.size()
    img_pixels = {}
    img_pixels.height = opts.info.size.height / opts.info.dpi.height * 96 * terminal_size.scale
    img_pixels.width = opts.info.size.width / opts.info.dpi.width * 96 * terminal_size.scale
  else
    img_pixels = M.dim(file)
  end
  local img_cells = M.pixels_to_cells(img_pixels)

  local ret = vim.deepcopy(cells)
  if img_cells.width <= cells.width and img_cells.height <= cells.height then
    return img_cells
  end
  ret.width = math.min(cells.width, img_cells.width)
  ret.height = math.min(cells.height, img_cells.height)

  local scale = ret.width / ret.height
  local img_scale = img_cells.width / img_cells.height
  local fit_height = math.floor(ret.width / img_scale + 0.5)
  local fit_width = math.floor(ret.height * img_scale + 0.5)

  if ret.height == fit_height or ret.width == fit_width then
    -- Image fits exactly
  elseif img_scale > scale then
    ret.height = fit_height
  else
    ret.width = fit_width
  end
  return M.norm(ret)
end

---@param src                            string
---@return string
function M.norm_src(src)
  if yoz.uri.is_data_uri(src) then
    return src
  end
  if src:find("^file://") then
    src = vim.uri_to_fname(src)
  end
  src = yoz.uri.decode(src)
  return dot.path.normalize(vim.fn.fnamemodify(src, ":p"))
end

---@param src                            string
---@return string, integer
function M.get_page(src)
  local parts = vim.split(src, "#page=", { plain = true })
  local page_number = tonumber(parts[2]) or 1
  return parts[1], page_number - 1
end

---The version of the file at `path` as it is on disk now; a data URI is addressed by its content and has none.
---@param path                          string
---@return string
function M.version(path)
  if yoz.uri.is_data_uri(path) then
    return ""
  end
  local stat = vim.uv.fs_stat(path)
  if stat == nil then
    return "missing"
  end
  -- ctime still changes when a tool restores the old mtime, and ino when a rename replaces the file.
  return table.concat({ stat.ino, stat.size, stat.mtime.sec, stat.mtime.nsec, stat.ctime.sec, stat.ctime.nsec }, ":")
end

---@param tpl                            string
---@param tpl_data                       table<string, string|number>
---@return string
function M.tpl(tpl, tpl_data)
  return (tpl:gsub("{([^}]+)}", function(key)
    return tostring(tpl_data[key] or "")
  end))
end

---Interpolate ${key} placeholders while leaving literal `{...}` (e.g. LaTeX braces) intact.
---@param tpl                            string
---@param tpl_data                       table<string, string|number>
---@return string
function M.tpl_env(tpl, tpl_data)
  return (tpl:gsub("%${([%w_]+)}", function(key)
    return tostring(tpl_data[key] or "")
  end))
end

---@param filename                       string
---@return boolean
function M.is_support_file(filename)
  -- macOS matches the BufReadCmd patterns regardless of case, so `IMG_0001.HEIC` reaches here too.
  local extname = yoz.path.extname(filename):lower() ---@type string
  return SUPPORTED_EXTNAME_SET[extname] == true
end

---@return boolean
function M.is_support_terminal()
  return env.supported
end

return M
