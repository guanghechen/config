---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.image.convert" ---@type string

---@class era.m.image.convert
local M = {}

local uv = vim.uv

---@alias era.m.image.args        (number|string)[] | fun(): ((number|string)[])

---@class era.m.image.convert.IConfig
---@field public notify                  boolean
---@field public mermaid                 ?era.m.image.args
---@field public magick                  ?table<string, era.m.image.args>
local config = {
  notify = false,
  mermaid = function()
    local theme = vim.o.background == "light" and "neutral" or "dark"
    return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-t", theme, "-s", "{scale}" }
  end,
  magick = {
    default = { "{coder}:{src}[0]", "-scale", "1920x1080>" },
    vector = { "-density", 192, "{coder}:{src}[{page}]" },
    math = { "-density", 192, "{coder}:{src}[{page}]", "-trim" },
    pdf = { "-density", 192, "{coder}:{src}[{page}]", "-background", "white", "-alpha", "remove", "-trim" },
  },
}

-- Inline-math uniform canvas height (px, @192dpi/12pt). Each math formula is bottom-aligned
-- (gravity south) onto a canvas of at least this height so placement's inline down-scaling
-- applies the same factor to every formula on a line — keeping the math em (e.g. `≤`) a
-- consistent size regardless of superscripts. South keeps baselines level; taller formulas
-- keep their own height via max().
local MATH_INLINE_H = 42
-- Descender gap (px) left below each formula so its baseline lands on the text baseline
-- rather than the cell floor (south-alignment alone makes inline math sit low). Tune to the
-- font's descender; small enough that superscript formulas still fit within MATH_INLINE_H.
local MATH_BASELINE_GAP = 6

-- ImageMagick reads whatever images a document references. With these limits a small file declaring huge
-- dimensions (a decompression bomb) fails at once instead of filling memory and the disk-backed pixel cache.
-- stylua: ignore
local MAGICK_LIMITS = {
  "-limit", "width", "16KP",
  "-limit", "height", "16KP",
  "-limit", "memory", "512MiB",
  "-limit", "disk", "2GiB",
}

---@param args                          (string|number)[]
---@return (string|number)[]
local function limited(args)
  return vim.list_extend(vim.deepcopy(MAGICK_LIMITS), args)
end

-- ImageMagick otherwise decodes a file as whatever its content says, so a `.png` holding PostScript would run
-- Ghostscript on it once that is installed. Named by extension, a file decodes only as these formats, or not at all.
-- stylua: ignore
local MAGICK_CODERS = {
  avif = "AVIF", bmp = "BMP", gif = "GIF", heic = "HEIC", heif = "HEIF", ico = "ICO", jpeg = "JPEG", jpg = "JPEG",
  png = "PNG", psd = "PSD", svg = "SVG", tga = "TGA", tif = "TIFF", tiff = "TIFF", webp = "WEBP",
  avi = "AVI", mkv = "MKV", mov = "MOV", mp4 = "MP4", webm = "WEBM",
}

---@class era.m.image.meta
---@field public src                     string
---@field public info                    ?era.m.image.Info
---@field public pdf                     ?string
---@field public kind                    ?string

---@class era.m.image.Proc
---@field public cmd                     string
---@field public cwd                     ?string
---@field public args                    era.m.image.args

---@class era.m.image.step
---@field public name                    string
---@field public file                    string
---@field public ft                      string
---@field public cmd                     era.m.image.cmd
---@field public meta                    era.m.image.meta
---@field public done                    ?boolean
---@field public err                     ?string
---@field public proc                    ?stl.c.Proc

---@class era.m.image.cmd
---@field public cmd                     (fun(step: era.m.image.step): (era.m.image.Proc|era.m.image.Proc[]))|era.m.image.Proc|era.m.image.Proc[]
---@field public ft                      ?string
---@field public file                    ?fun(convert: era.m.image.Convert, meta: era.m.image.meta): string
---@field public depends                 ?string[]
---@field public on_done                 ?fun(step: era.m.image.step)
---@field public on_error                ?fun(step: era.m.image.step): boolean|nil
---@field public pipe                    ?boolean
---@field public atomic                  ?boolean Renamed into place once whole: complete when its file exists, apart from the marker

---@type table<string, era.m.image.cmd>
local commands = {
  icns = {
    ft = "png",
    cmd = {
      {
        cmd = "sips",
        args = { "-s", "format", "png", "{src}", "--out", "{file}" },
      },
    },
  },
  typ = {
    ft = "pdf",
    cmd = {
      {
        cmd = "typst",
        args = { "compile", "--format", "pdf", "--pages", 1, "{src}", "{file}" },
      },
    },
  },
  tex = {
    ft = "pdf",
    file = function(convert, ctx)
      local s = require("era.m.image.state").data
      ctx.pdf = s.tmpdir .. "/" .. vim.fs.basename(ctx.src):gsub("%.tex$", ".pdf")
      return convert:tmpfile("pdf")
    end,
    cmd = {
      {
        cwd = "{dirname}",
        cmd = "tectonic",
        args = { "-Z", "continue-on-errors", "--outdir", "{tmpdir}", "{src}" },
      },
      {
        cmd = "pdflatex",
        cwd = "{dirname}",
        args = { "-output-directory={tmpdir}", "-interaction=nonstopmode", "{src}" },
      },
    },
    on_done = function(step)
      local pdf = assert(step.meta.pdf, "No pdf file") --[[@as string]]
      if uv.fs_stat(pdf) then
        uv.fs_rename(pdf, step.file)
      end
    end,
    on_error = function(step)
      local pdf = assert(step.meta.pdf, "No pdf file") --[[@as string]]
      if step.meta.pdf and vim.fn.getfsize(pdf) > 0 then
        return true
      end
    end,
  },
  mmd = {
    cmd = {
      cmd = "mmdc",
      args = config.mermaid,
    },
    file = function(convert, _)
      return convert:tmpfile(vim.o.background .. ".png")
    end,
  },
  identify = {
    pipe = false,
    file = function(convert, _)
      return convert:tmpfile(convert:ft() .. ".info")
    end,
    cmd = {
      {
        cmd = "magick",
        args = vim.list_extend(
          { "identify" },
          limited({ "-units", "PixelsPerInch", "-format", "%m %[fx:w]x%[fx:h] %xx%y", "{coder}:{src}[{page}]" })
        ),
      },
      {
        cmd = "identify",
        args = limited({ "-units", "PixelsPerInch", "-format", "%m %[fx:w]x%[fx:h] %xx%y", "{coder}:{src}[{page}]" }),
      },
    },
    on_done = function(step)
      local file = step.file
      if step.proc then
        local fd = assert(io.open(file, "w"), "Failed to open file: " .. file)
        fd:write(step.proc:out())
        fd:close()
      end
      local fd = assert(io.open(file, "r"), "Failed to open file: " .. file)
      local info = vim.trim(fd:read("*a"))
      fd:close()
      local format, w, h, x, y = info:match("^(%w+)%s+(%d+)x(%d+)%s+(%d+%.?%d*)x(%d+%.?%d*)$")
      if not format then
        return
      end
      step.meta.info = {
        format = format:lower(),
        size = { width = tonumber(w) or 0, height = tonumber(h) or 0 },
        dpi = { width = tonumber(x) or 0, height = tonumber(y) or 0 },
      }
    end,
  },
  pdf = {
    ft = "png",
    cmd = function(step)
      -- Rasterize PDF with poppler so ImageMagick never delegates to ghostscript.
      -- Math stays transparent (like the old magick.math preset); pdftoppm has no
      -- -transp, so for math we require pdftocairo and fail fast instead of silently
      -- rendering an opaque (invisible-on-dark) glyph. Direct PDFs keep poppler's
      -- default white page background and may fall back to pdftoppm.
      local is_math = step.meta.kind == "math"
      local args = { "-png", "-r", 192, "-f", "{page1}", "-l", "{page1}", "-singlefile" }
      if is_math then
        args[#args + 1] = "-transp"
      end
      vim.list_extend(args, { "{src}", "{stem}" })
      local cmds = { { cmd = "pdftocairo", args = args } }
      if not is_math then
        cmds[#cmds + 1] = { cmd = "pdftoppm", args = vim.deepcopy(args) }
      end
      return cmds
    end,
  },
  trim = {
    file = function(convert, _)
      return convert:tmpfile("trim.png")
    end,
    cmd = function(step)
      -- PNG-only crop (never decodes PDF/PS) to restore the old `-trim` without ghostscript.
      -- Inline math is additionally padded to a uniform height (MATH_INLINE_H) so that
      -- every formula on a line is down-scaled by the same factor, keeping glyphs like
      -- `≤` a consistent size. `convert` (IM6) lacks `%[fx:]`, so it degrades to a plain crop.
      local magick_args = limited({ "{coder}:{src}", "-trim", "+repage" })
      local convert_args = limited({ "{coder}:{src}", "-trim", "+repage" })
      if step.meta.kind == "math" then
        vim.list_extend(magick_args, {
          "-background",
          "none",
          "-gravity",
          "south",
          "-splice",
          "0x" .. MATH_BASELINE_GAP,
          "-extent",
          "x%[fx:max(" .. MATH_INLINE_H .. ",h)]",
        })
      end
      magick_args[#magick_args + 1] = "{file}"
      convert_args[#convert_args + 1] = "{file}"
      return {
        { cmd = "magick", args = magick_args },
        { cmd = "convert", args = convert_args },
      }
    end,
  },
  -- Formulas are typeset in black and take their color last, so a theme change recolors them rather than typesetting
  -- them again; each color keeps its own file.
  tint = {
    atomic = true,
    file = function(convert, _)
      return convert:tmpfile(convert.color .. ".tint.png")
    end,
    cmd = function()
      -- The default ink takes the color, a color the formula names stays. The black of an opaque copy is replaced and
      -- the alpha put back, so the partly transparent edges of antialiasing change with it. Black ink alone is read as
      -- grayscale, which would turn the color into a gray.
      -- stylua: ignore
      local args = limited({
        "{coder}:{src}", "-colorspace", "sRGB", "-write", "mpr:ink",
        "-alpha", "off", "-fill", "#{color}", "-opaque", "black",
        "(", "mpr:ink", "-alpha", "extract", ")",
        "-compose", "CopyOpacity", "-composite", "PNG:{file}.part",
      })
      return {
        { cmd = "magick", args = args },
        { cmd = "convert", args = args },
      }
    end,
    on_done = function(step)
      uv.fs_rename(step.file .. ".part", step.file)
    end,
  },
  convert = {
    ft = "png",
    cmd = function(step)
      local formats = vim.deepcopy(config.magick or {})
      local args = formats.default or { "{coder}:{src}[{page}]" }
      local info = step.meta.info
      local format = info and info.format or vim.fs.ext(step.meta.src)

      local vector = vim.list_contains({ "pdf", "svg" }, format)
      if vector then
        args = formats.vector or args
      end

      local fts = { vim.fs.basename(step.file):match("%.([^%.]+)%.png") } ---@type string[]
      fts[#fts + 1] = format

      for _, ft in ipairs(fts) do
        local fmt = formats[ft]
        if fmt then
          args = type(fmt) == "function" and fmt() or fmt
          break
        end
      end
      args = type(args) == "function" and args() or args
      ---@cast args (string|number)[]

      args = limited(args)
      vim.list_extend(args, { "-write", "{file}", "-identify", "-format", "%m %[fx:w]x%[fx:h] %xx%y", "{file}.info" })
      return {
        { cmd = "magick", args = args },
        not stl.env.IS_WIN and { cmd = "convert", args = args } or nil,
      }
    end,
  },
}

---@type table<string, boolean>
local have = {}

---@type stl.c.Proc[]
local proc_queue = {}

---@type integer
local proc_running = 0

local MAX_PROCS = 3

---@param proc                           ?stl.c.Proc
---@return nil
local function schedule(proc)
  if proc then
    table.insert(proc_queue, proc)
  else
    proc_running = proc_running - 1
  end
  if proc_running < MAX_PROCS and #proc_queue > 0 then
    proc_running = proc_running + 1
    proc = table.remove(proc_queue, 1)
    proc:run()
  end
end

---@param step                           era.m.image.step
---@return era.m.image.Proc|nil
local function get_cmd(step)
  local cmd = step.cmd.cmd
  cmd = type(cmd) == "function" and cmd(step) or cmd
  local cmds = cmd.cmd and { cmd } or cmd
  ---@cast cmds era.m.image.Proc[]
  for _, c in ipairs(cmds) do
    if have[c.cmd] == nil then
      have[c.cmd] = vim.fn.executable(c.cmd) == 1
    end
    if have[c.cmd] then
      return c
    end
  end
end

-- How long the cache keeps a file that no conversion has used.
local CACHE_DAYS = 30

---@type boolean
local cache_prepared = false

---Readies the cache before the first conversion of a session looks into it. The cache holds renders of the documents
---opened and the source of their formulas, so it is for this account only; what no conversion used for CACHE_DAYS
---goes, which is only what a hash names (see `Convert:__touch__`).
---@param dir                           string
---@return nil
local function prepare_cache(dir)
  if cache_prepared then
    return
  end
  cache_prepared = true
  stl.env.mkdirs(dir, true)
  uv.fs_chmod(dir, tonumber("700", 8))
  local expired = os.time() - CACHE_DAYS * 24 * 3600 ---@type integer
  for name, kind in vim.fs.dir(dir) do
    if kind == "file" and name:find("^%x%x%x%x%x%x%x%x") then
      local path = dir .. "/" .. name ---@type string
      local stat = uv.fs_stat(path)
      if stat ~= nil and stat.mtime.sec < expired then
        uv.fs_unlink(path)
      end
    end
  end
end

---@class era.m.image.Convert
---@field public opts                    era.m.image.convert.Opts
---@field public src                     string
---@field public page                    integer
---@field public file                    string
---@field public prefix                  string
---@field public marker                 string
---@field public color                  ?string
---@field public meta                    era.m.image.meta
---@field public steps                   era.m.image.step[]
---@field public aborted                 ?boolean
---@field public discarded              ?boolean
---@field protected _cached             boolean
---@field protected _started            ?number
---@field protected _done                ?boolean
---@field protected _err                 ?string
---@field protected _future              stl.c.Future
---@field protected _step                integer
---@field protected _tpl_data            table<string, string>
local Convert = {}
Convert.__index = Convert

---@class era.m.image.convert.Source
---@field public id                     string
---@field public path                   string
---@field public page                   integer
---@field public version                string

---@class era.m.image.convert.Opts
---@field public source                 era.m.image.convert.Source
---@field public color                  ?string The color formulas are drawn in, as `RRGGBB`

---@param opts                           era.m.image.convert.Opts
---@return era.m.image.Convert
function Convert.new(opts)
  local state = require("era.m.image.state")
  local s = state.data
  prepare_cache(s.tmpdir)
  local self = setmetatable({}, Convert)
  local src = opts.source.path ---@type string
  self.page = opts.source.page

  if yoz.uri.is_data_uri(src) then
    src = self:__decode_data_uri__(src, s.tmpdir)
  end

  self.opts = opts
  self.src = src
  self._step = 0
  self._future = stl.c.Future.new()
  local base = vim.fn.fnamemodify(src, ":t:r")
  -- Named after the source version: an edited source is converted again rather than read from the cache, and a
  -- conversion never writes over the files of another version that may still be on screen.
  local key = src .. self.page .. opts.source.version ---@type string
  self.prefix = vim.fn.sha256(key):sub(1, 8) .. "-" .. base:gsub("[^%w%.]+", "-")
  -- Outputs are reused only after a whole pipeline wrote them; an interrupted run leaves files but no marker.
  self.marker = self:tmpfile("done")
  self._cached = uv.fs_stat(self.marker) ~= nil
  -- kind is inferred only from the module-generated template extension (.math.tex),
  -- never from a user's direct file, so e.g. a direct `paper.math.pdf` is not treated as math.
  self.meta = { src = src, kind = src:match("%.(%w+)%.tex$") }
  self.color = self.meta.kind == "math" and opts.color or nil
  self.steps = {}
  local terminal = require("era.m.image.terminal")
  self._tpl_data = {
    tmpdir = s.tmpdir,
    bg = vim.o.background,
    scale = tostring(terminal.size().scale or 1),
    color = self.color,
  }
  self:__resolve__()
  if self._cached then
    self:__touch__()
  end
  return self
end

---Marks the outputs of a reused conversion as used, so that `prepare_cache` keeps them. The source keeps its times,
---which make its version.
---@return nil
function Convert:__touch__()
  local now = os.time() ---@type integer
  uv.fs_utime(self.marker, now, now)
  for _, step in ipairs(self.steps) do
    uv.fs_utime(step.file, now, now)
  end
end

---@return era.m.image.step|nil
function Convert:current()
  return self.steps[self._step]
end

---@return boolean
function Convert:ready()
  return self:done() and not self:error()
end

---@return boolean
function Convert:done()
  return self._done or false
end

---@return string|nil
function Convert:error()
  return self._err
end

---@return stl.c.Future Resolves with self (era.m.image.Convert)
function Convert:future()
  return self._future
end

---@param ft                             string
---@return string
function Convert:tmpfile(ft)
  local s = require("era.m.image.state").data
  return s.tmpdir .. "/" .. self.prefix .. "." .. ft
end

---@param src                            ?string
---@return string
function Convert:ft(src)
  return vim.fs.ext(src or self.meta.src):lower()
end

---@return nil
function Convert:run()
  if #self.steps == 0 then
    return self:__on_done__()
  end

  if vim.fn.filereadable(self.src) == 0 then
    self._err = ("File not found\n- `%s`"):format(vim.fn.fnamemodify(self.src, ":p:~"))
    return self:__on_done__()
  end

  local sec, usec = uv.gettimeofday()
  self._started = sec + usec / 1e6
  self:__step__()
end

---@return nil
function Convert:abort()
  if self.aborted then
    return
  end
  if self:done() then
    return
  end
  self.aborted = true
  self._err = "Aborted"
  for _, step in ipairs(self.steps) do
    if step.proc then
      step.proc:kill()
    end
  end
end

---Abort the conversion and delete the files it wrote once no step is writing them.
---@return nil
function Convert:discard()
  if self.discarded then
    return
  end
  self.discarded = true
  if self:done() then
    return self:__clean__()
  end
  self:abort()
end

----------------------------------------------------------------------------------------------------

---Deletes only files this conversion named directly inside the cache directory, never its source.
---@return nil
function Convert:__clean__()
  local tmpdir = require("era.m.image.state").data.tmpdir ---@type string
  local files = { self.marker } ---@type string[]
  for _, step in ipairs(self.steps) do
    files[#files + 1] = step.file
  end
  for _, file in ipairs(files) do
    if file ~= self.src and file == tmpdir .. "/" .. vim.fs.basename(file) then
      uv.fs_unlink(file)
    end
  end
end

---@param data_uri                       string
---@param tmpdir                         string
---@return string
function Convert:__decode_data_uri__(data_uri, tmpdir)
  local mime, encoding, data = data_uri:match("^data:([^;,]+);?([^,]*),(.+)$")
  if not mime or not data then
    return data_uri
  end

  local ext = "png"
  if mime:find("^image/") then
    ext = mime:gsub("^image/", "")
    if ext == "jpeg" then
      ext = "jpg"
    elseif ext == "svg+xml" then
      ext = "svg"
    elseif ext == "x-icon" or ext == "vnd.microsoft.icon" then
      ext = "ico"
    end
  end
  -- The type is the document's to write: it may name a format, never a path.
  ext = ext:gsub("%W", "")

  local hash = vim.fn.sha256(data):sub(1, 12)
  local filepath = tmpdir .. "/" .. hash .. "." .. ext

  if vim.fn.filereadable(filepath) == 1 then
    return filepath
  end

  local decoded ---@type string|nil
  -- `base64` is the last parameter, after any others such as `charset=utf-8`.
  if (";" .. encoding):find(";base64$") then
    -- Accept what browsers do: line breaks, the URL-safe alphabet and missing padding.
    local base64 = data:gsub("%s", ""):gsub("-", "+"):gsub("_", "/") ---@type string
    base64 = base64 .. string.rep("=", (4 - #base64 % 4) % 4)
    local ok, result = pcall(vim.base64.decode, base64)
    decoded = ok and result or nil
  else
    decoded = yoz.uri.decode(data)
  end
  -- Undecodable data fails its own conversion, like any URI that is not a file, rather than raising.
  if decoded == nil then
    return data_uri
  end

  local fd = io.open(filepath, "wb")
  if fd then
    fd:write(decoded)
    fd:close()
  end

  return filepath
end

---@param target                         string
---@return nil
function Convert:__resolve_target__(target)
  local cmd = assert(commands[target], "No command for target: " .. target)
  assert(cmd.file or cmd.ft, "No file or ft for target: " .. target)
  for _, dep in ipairs(cmd.depends or {}) do
    self:__resolve_target__(dep)
  end
  local file = cmd.file and cmd.file(self, self.meta) or self:tmpfile(cmd.ft)
  local done = self._cached ---@type boolean
  if cmd.atomic then
    done = uv.fs_stat(file) ~= nil
  end
  ---@type era.m.image.step
  local step = {
    name = target,
    file = file,
    ft = self:ft(file),
    meta = self.meta,
    done = done,
    cmd = cmd,
  }
  if cmd.pipe ~= false then
    self.meta = setmetatable({ src = file }, { __index = self.meta })
  end
  table.insert(self.steps, step)
end

---@return nil
function Convert:__resolve__()
  local from_pdf = false
  while self:ft() ~= "png" do
    local ft = self:ft()
    if ft == "pdf" then
      from_pdf = true
    end
    local target = commands[ft] and ft or "convert"
    if self:__resolve_target__(target) then
      break
    end
  end
  if from_pdf then
    self:__resolve_target__("trim")
  end
  self:__resolve_target__("identify")
  if self.color then
    self:__resolve_target__("tint")
  end
  self.file = self.meta.src
end

---@param err                            ?string
---@return nil
function Convert:__on_step__(err)
  local step = assert(self:current(), "No current step")
  step.done = true
  step.err = err
  if self.aborted then
    return self:__on_done__()
  end
  if step and err and step.cmd.on_error and step.cmd.on_error(step) then
    -- keep going
  elseif err then
    self._err = err
    return self:__on_done__()
  end
  if step and step.cmd.on_done then
    step.cmd.on_done(step)
  end

  if self._step < #self.steps then
    self:__step__()
  else
    self:__on_done__()
  end
end

---@return nil
function Convert:__on_done__()
  local step = self:current()
  self._done = true
  if self.discarded then
    self:__clean__()
  elseif not self._err and not self._cached then
    local fd = io.open(self.marker, "w")
    if fd then
      fd:close()
    end
  end
  if self._err and config.notify then
    local title = step and ("Conversion failed at step `%s`"):format(step.name) or "Conversion failed"
    stl.reporter.error({
      from = __module_name__,
      subject = title,
      message = self._err,
    })
  end
  self._future:__resolve__(self) ---@diagnostic disable-line: invisible
end

---@return nil
function Convert:__step__()
  local state = require("era.m.image.state")
  self._step = self._step + 1
  assert(self._step <= #self.steps, "No more steps")

  local step = self.steps[self._step]
  -- An earlier step of this run may have written the output already (`convert` writes the `.info` that `identify`
  -- would), or another process may have finished this version; an output older than this run may be partial.
  local stat = uv.fs_stat(step.file)
  if step.cmd.atomic then
    step.done = stat ~= nil
  else
    local written = stat ~= nil and stat.mtime.sec + stat.mtime.nsec / 1e9 >= self._started
    step.done = step.done or written or (uv.fs_stat(self.marker) ~= nil)
  end
  if step.done then
    return self:__on_step__()
  end

  local cmd = get_cmd(step)
  if not cmd then
    return self:__on_step__("No command available")
  end

  local args = type(cmd.args) == "function" and cmd.args() or cmd.args
  ---@cast args (number|string)[]
  args = vim.deepcopy(args)

  local ext = vim.fs.ext(step.meta.src):lower() ---@type string
  local data = vim.tbl_extend("keep", {
    file = step.file,
    basename = vim.fs.basename(step.file),
    name = vim.fn.fnamemodify(step.file, ":t:r"),
    stem = vim.fn.fnamemodify(step.file, ":r"),
    dirname = vim.fs.dirname(step.meta.src),
    src = step.meta.src,
    coder = MAGICK_CODERS[ext],
    page = self.page,
    page1 = self.page + 1,
  }, self._tpl_data)

  for a, arg in ipairs(args) do
    if type(arg) == "string" then
      -- ImageMagick reads nothing but the formats it is named for here.
      if data.coder == nil and arg:find("{coder}", 1, true) then
        return self:__on_step__(("Unsupported image format `%s`"):format(ext == "" and "(no extension)" or "." .. ext))
      end
      args[a] = state.tpl(arg, data)
    end
  end

  local timeout = state.data.convert_timeout ---@type integer
  step.proc = stl.c.Proc.new({
    run = false,
    timeout = timeout,
    cwd = cmd.cwd and state.tpl(cmd.cwd, data) or nil,
    cmd = cmd.cmd,
    args = args,
    on_exit = function(proc, err)
      schedule()
      local out = vim.trim(proc:out() .. "\n" .. proc:err())
      if proc.timed_out then
        out = vim.trim(("%s timed out after %d ms\n%s"):format(cmd.cmd, timeout, out))
      end
      vim.schedule(function()
        self:__on_step__(err and out or nil)
      end)
    end,
  })
  schedule(step.proc)
end

---@param opts                           era.m.image.convert.Opts
---@return era.m.image.Convert
function M.convert(opts)
  return Convert.new(opts)
end

---@param path                          string
---@return string
function M.version(path)
  return require("era.m.image.state").version(path)
end

---@param src                           string
---@return era.m.image.convert.Source
function M.source(src)
  local state = require("era.m.image.state")
  local path, page = state.get_page(src)
  path = state.norm_src(path)
  return { id = path .. "#" .. page, path = path, page = page, version = state.version(path) }
end

return M
