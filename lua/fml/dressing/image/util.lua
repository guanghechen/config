local terminal = require("fml.dressing.image.terminal")

---@class fml.dressing.image.util
local M = {}

local dims = {} ---@type table<string, fml.dressing.image.Size>

--- Get the dimensions of a PNG file
---@param filepath                      string
---@return fml.dressing.image.Size
function M.dim(filepath)
  filepath = vim.fs.normalize(filepath)
  if dims[filepath] then
    return dims[filepath]
  end

  -- extract header with IHDR chunk
  local fd = assert(io.open(filepath, "rb"), "Failed to open file: " .. filepath)
  local header = fd:read(24) ---@type string
  fd:close()

  -- Check PNG signature
  assert(string.sub(header, 1, 8) == "\137PNG\r\n\26\n", "Not a valid PNG file: " .. filepath)

  -- Extract width and height from the IHDR chunk
  local width = string.byte(header, 17) * 16777216 + string.byte(header, 18) * 65536 + string.byte(header, 19) * 256 + string.byte(header, 20)
  local height = string.byte(header, 21) * 16777216 + string.byte(header, 22) * 65536 + string.byte(header, 23) * 256 + string.byte(header, 24)
  dims[filepath] = { width = width, height = height }
  return dims[filepath]
end

---@param size                          fml.dressing.image.Size
---@return fml.dressing.image.Size
function M.pixels_to_cells(size)
  local terminal_size = terminal.size()
  return M.norm({
    width = size.width / terminal_size.cell_width,
    height = size.height / terminal_size.cell_height,
  })
end

---@param size                          fml.dressing.image.Size
---@return fml.dressing.image.Size
function M.norm(size)
  local width = math.max(1, math.ceil(size.width)) ---@type integer
  local height = math.max(1, math.ceil(size.height)) ---@type integer
  return { width = width, height = height }
end

---@param filepath                      string
---@param cells                         fml.dressing.image.Size  size in rows x columns
---@param opts                          ?{ full?: boolean, info?: fml.dressing.image.Info }
function M.fit(filepath, cells, opts)
  opts = opts or {}
  local img_pixels ---@type fml.dressing.image.Size
  if opts.info then
    local terminal_size = terminal.size()
    img_pixels = {}
    img_pixels.height = opts.info.size.height / opts.info.dpi.height * 96 * terminal_size.scale
    img_pixels.width = opts.info.size.width / opts.info.dpi.width * 96 * terminal_size.scale
  else
    img_pixels = M.dim(filepath)
  end
  local img_cells = M.pixels_to_cells(img_pixels)

  local ret = vim.deepcopy(cells)
  -- if not opts.full then
  if img_cells.width <= cells.width and img_cells.height <= cells.height then
    return img_cells
  end
  ret.width = math.min(cells.width, img_cells.width)
  ret.height = math.min(cells.height, img_cells.height)
  -- end

  local scale = ret.width / ret.height
  local img_scale = img_cells.width / img_cells.height
  local fit_height = math.floor(ret.width / img_scale + 0.5)
  local fit_width = math.floor(ret.height * img_scale + 0.5)

  if ret.height == fit_height or ret.width == fit_width then
    -- Image fits exactly
  elseif img_scale > scale then
    -- Image is wider relative to height - fit to width
    ret.height = fit_height
  else
    -- Image is taller relative to width - fit to height
    ret.width = fit_width
  end
  return M.norm(ret)
end

---@param str                           string
---@param data                          table<string, string>
---@param opts                          ?{ prefix?: string, indent?: boolean, offset?: number[] }
function M.tpl(str, data, opts)
  opts = opts or {}
  local ret = (
    str:gsub(
      "(" .. vim.pesc(opts.prefix or "") .. "%b{}" .. ")",
      ---@param w                       string
      ---@return string
      function(w)
        local inner = string.sub(w, 2 + #(opts.prefix or ""), -2)
        local key, default = inner:match("^(.-):(.*)$")
        local ret = data[key or inner]
        if ret == "" and default then
          return default
        end
        return ret or w
      end
    )
  )
  if opts.indent then
    local lines = vim.split(ret:gsub("\t", "  "), "\n", { plain = true })
    local indent = 1000
    for _, line in ipairs(lines) do
      indent = math.min(indent, line:find("%S") or 1000)
    end
    for l, line in ipairs(lines) do
      lines[l] = string.sub(line, indent)
    end
  end
  return ret
end

return M
