---@type string|nil
local terminal_name = nil
if dot.env.IS_KITTY then
  terminal_name = "kitty"
elseif dot.env.IS_WEZTERM then
  terminal_name = "wezterm"
elseif dot.env.IS_GHOSTTY then
  terminal_name = "ghostty"
end

---@class fml.dressing.image.state.env
---@field public name                    string
---@field public placeholders            boolean
---@field public remote                  boolean
---@field public supported               boolean
---@field public transform               ?fun(data: string): string
local env = {
  name = terminal_name or "",
  placeholders = terminal_name == "kitty" or terminal_name == "ghostty",
  remote = false,
  supported = terminal_name ~= nil,
}

if dot.env.IS_TMUX then
  env.name = env.name ~= "" and (env.name .. "/tmux") or "tmux"
  env.transform = function(data)
    return ("\027Ptmux;" .. data:gsub("\027", "\027\027")) .. "\027\\"
  end
end

---@class fml.dressing.image.state.data
---@field public resolve                 ?fun(file: string, src: string): string|nil
---@field public wo                      ?table<string, any>
local data = {
  tmpdir = std.path.join(vim.fn.stdpath("cache"), "image/"),
  convert = {
    notify = true,
    ---@type fml.dressing.image.args
    mermaid = function()
      local theme = vim.o.background == "light" and "neutral" or "dark"
      return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-t", theme, "-s", "{scale}" }
    end,
    ---@type table<string, fml.dressing.image.args>
    magick = {
      default = { "{src}[0]", "-scale", "1920x1080>" },
      vector = { "-density", 192, "{src}[0]" },
      math = { "-density", 192, "{src}[0]", "-trim" },
      pdf = { "-density", 192, "{src}[0]", "-background", "white", "-alpha", "remove", "-trim" },
    },
  },
  doc = {
    enabled = true,
    inline = true,
    float = true,
    max_width = 80,
    max_height = 40,
    ---@param lang                      string
    ---@param type                      fml.dressing.image.Type
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
      font_size = "Large",
      packages = { "amsmath", "amssymb", "amsfonts", "amscd", "mathtools" },
      tpl = [[
        \documentclass[preview,border=0pt,varwidth,12pt]{standalone}
        \usepackage{${packages}}
        \begin{document}
        ${header}
        { \${font_size} \selectfont
          \color[HTML]{${color}}
        ${content}}
        \end{document}]],
    },
    typst = {
      tpl = [[
        #set page(width: auto, height: auto, margin: (x: 2pt, y: 2pt))
        #show math.equation.where(block: false): set text(top-edge: "bounds", bottom-edge: "bounds")
        #set text(size: 12pt, fill: rgb("${color}"))
        ${header}
        ${content}]],
    },
  },
}

local SUPPORTED_EXTNAME_SET = ark.table.to_string_set(data.extnames) ---@type table<string, boolean>

---@alias fml.dressing.image.Size         {width: integer, height: integer}

---@alias fml.dressing.image.Pos          {[1]: integer, [2]: integer}

---@alias fml.dressing.image.Loc          fml.dressing.image.Pos|fml.dressing.image.Size|{zindex?: integer}

---@alias fml.dressing.image.Type         "image"|"math"|"chart"

---@class fml.dressing.image.Info
---@field public format                  string
---@field public size                    fml.dressing.image.Size
---@field public dpi                     fml.dressing.image.Size

---@type table<string, fml.dressing.image.Size>
local dims = {}

---@class fml.dressing.image.state
---@field public data                    fml.dressing.image.state.data
---@field public did_setup               boolean
---@field public env                     fml.dressing.image.state.env
local M = {
  data = data,
  did_setup = false,
  env = env,
}

---@param file                           string
---@return fml.dressing.image.Size
function M.dim(file)
  file = std.path.normalize(file)
  if dims[file] then
    return dims[file]
  end
  local fd = assert(io.open(file, "rb"), "Failed to open file: " .. file)
  local header = fd:read(24) ---@type string
  fd:close()
  assert(header:sub(1, 8) == "\137PNG\r\n\26\n", "Not a valid PNG file: " .. file)
  local width = header:byte(17) * 16777216 + header:byte(18) * 65536 + header:byte(19) * 256 + header:byte(20)
  local height = header:byte(21) * 16777216 + header:byte(22) * 65536 + header:byte(23) * 256 + header:byte(24)
  dims[file] = { width = width, height = height }
  return dims[file]
end

---@param size                           fml.dressing.image.Size
---@return fml.dressing.image.Size
function M.pixels_to_cells(size)
  local terminal = require("fml.dressing.image.terminal")
  local term_size = terminal.size()
  return M.norm({
    width = size.width / term_size.cell_width,
    height = size.height / term_size.cell_height,
  })
end

---@param size                           fml.dressing.image.Size
---@return fml.dressing.image.Size
function M.norm(size)
  return {
    width = math.max(1, math.ceil(size.width)),
    height = math.max(1, math.ceil(size.height)),
  }
end

---@param file                           string
---@param cells                          fml.dressing.image.Size
---@param opts                           ?{ full?: boolean, info?: fml.dressing.image.Info }
---@return fml.dressing.image.Size
function M.fit(file, cells, opts)
  opts = opts or {}
  local terminal = require("fml.dressing.image.terminal")
  local img_pixels ---@type fml.dressing.image.Size
  if opts.info then
    local term_size = terminal.size()
    img_pixels = {}
    img_pixels.height = opts.info.size.height / opts.info.dpi.height * 96 * term_size.scale
    img_pixels.width = opts.info.size.width / opts.info.dpi.width * 96 * term_size.scale
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
  if std.uri.is_data_uri(src) then
    return src
  end
  if src:find("^file://") then
    src = vim.uri_to_fname(src)
  end
  src = std.uri.decode(src)
  return std.path.normalize(vim.fn.fnamemodify(src, ":p"))
end

---@param src                            string
---@return string, integer
function M.get_page(src)
  local parts = vim.split(src, "#page=", { plain = true })
  local page_number = tonumber(parts[2]) or 1
  return parts[1], page_number - 1
end

---@param tpl                            string
---@param tpl_data                       table<string, string|number>
---@return string
function M.tpl(tpl, tpl_data)
  return (tpl:gsub("{([^}]+)}", function(key)
    return tostring(tpl_data[key] or "")
  end))
end

---@param filename                       string
---@return boolean
function M.is_support_file(filename)
  local extname = yoz.path.extname(filename) ---@type string
  return SUPPORTED_EXTNAME_SET[extname] == true
end

---@return boolean
function M.is_support_terminal()
  return env.supported
end

return M
