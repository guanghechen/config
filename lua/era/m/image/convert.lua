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
    default = { "{src}[0]", "-scale", "1920x1080>" },
    vector = { "-density", 192, "{src}[{page}]" },
    math = { "-density", 192, "{src}[{page}]", "-trim" },
    pdf = { "-density", 192, "{src}[{page}]", "-background", "white", "-alpha", "remove", "-trim" },
  },
}

---@class era.m.image.meta
---@field public src                     string
---@field public info                    ?era.m.image.Info
---@field public pdf                     ?string

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
        args = { "identify", "-units", "PixelsPerInch", "-format", "%m %[fx:w]x%[fx:h] %xx%y", "{src}[{page}]" },
      },
      {
        cmd = "identify",
        args = { "-units", "PixelsPerInch", "-format", "%m %[fx:w]x%[fx:h] %xx%y", "{src}[{page}]" },
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
      -- For math, add transparent vertical padding so the glyph sits below full line-height
      -- (matches surrounding text) instead of filling the whole cell.
      local args = { "{src}", "-trim", "+repage" }
      if step.meta.kind == "math" then
        vim.list_extend(args, { "-bordercolor", "none", "-border", "0x12%" })
      end
      args[#args + 1] = "{file}"
      return {
        { cmd = "magick", args = args },
        { cmd = "convert", args = vim.deepcopy(args) },
      }
    end,
  },
  convert = {
    ft = "png",
    cmd = function(step)
      local formats = vim.deepcopy(config.magick or {})
      local args = formats.default or { "{src}[{page}]" }
      local info = step.meta.info
      local format = info and info.format or vim.fn.fnamemodify(step.meta.src, ":e")

      local vector = vim.tbl_contains({ "pdf", "svg", "eps", "ai", "mvg" }, format)
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

---@class era.m.image.Convert
---@field public opts                    era.m.image.convert.Opts
---@field public src                     string
---@field public page                    integer
---@field public file                    string
---@field public prefix                  string
---@field public meta                    era.m.image.meta
---@field public steps                   era.m.image.step[]
---@field public aborted                 ?boolean
---@field protected _done                ?boolean
---@field protected _err                 ?string
---@field protected _future              stl.c.Future
---@field protected _step                integer
---@field protected _tpl_data            table<string, string>
local Convert = {}
Convert.__index = Convert

---@class era.m.image.convert.Opts
---@field public src                     string

---@param opts                           era.m.image.convert.Opts
---@return era.m.image.Convert
function Convert.new(opts)
  local state = require("era.m.image.state")
  local s = state.data
  stl.env.mkdirs(s.tmpdir, true)
  local self = setmetatable({}, Convert)
  opts.src, self.page = state.get_page(opts.src)
  opts.src = state.norm_src(opts.src)

  if yoz.uri.is_data_uri(opts.src) then
    opts.src = self:__decode_data_uri__(opts.src, s.tmpdir)
  end

  self.opts = opts
  self.src = opts.src
  self._step = 0
  self._future = stl.c.Future.new()
  local base = vim.fn.fnamemodify(opts.src, ":t:r")
  self.prefix = vim.fn.sha256(self.opts.src .. self.page):sub(1, 8) .. "-" .. base:gsub("[^%w%.]+", "-")
  -- kind is inferred only from module-generated template extensions (.math.tex / .math.typ),
  -- never from a user's direct file, so e.g. a direct `paper.math.pdf` is not treated as math.
  self.meta = { src = opts.src, kind = opts.src:match("%.(%w+)%.tex$") or opts.src:match("%.(%w+)%.typ$") }
  self.steps = {}
  local terminal = require("era.m.image.terminal")
  self._tpl_data = {
    tmpdir = s.tmpdir,
    bg = vim.o.background,
    scale = tostring(terminal.size().scale or 1),
  }
  self:__resolve__()
  return self
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
  return vim.fn.fnamemodify(src or self.meta.src, ":e"):lower()
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

----------------------------------------------------------------------------------------------------

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
    end
  end

  local hash = vim.fn.sha256(data):sub(1, 12)
  local filepath = tmpdir .. "/" .. hash .. "." .. ext

  if vim.fn.filereadable(filepath) == 1 then
    return filepath
  end

  local decoded ---@type string
  if encoding == "base64" then
    decoded = vim.base64.decode(data)
  else
    decoded = yoz.uri.decode(data)
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
  ---@type era.m.image.step
  local step = {
    name = target,
    file = file,
    ft = self:ft(file),
    meta = self.meta,
    done = uv.fs_stat(file) ~= nil,
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
  step.done = step.done or (uv.fs_stat(step.file) ~= nil)
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

  local data = vim.tbl_extend("keep", {
    file = step.file,
    basename = vim.fs.basename(step.file),
    name = vim.fn.fnamemodify(step.file, ":t:r"),
    stem = vim.fn.fnamemodify(step.file, ":r"),
    dirname = vim.fs.dirname(step.meta.src),
    src = step.meta.src,
    page = self.page,
    page1 = self.page + 1,
  }, self._tpl_data)

  for a, arg in ipairs(args) do
    if type(arg) == "string" then
      args[a] = state.tpl(arg, data)
    end
  end

  step.proc = stl.c.Proc.new({
    run = false,
    cwd = cmd.cwd and state.tpl(cmd.cwd, data) or nil,
    cmd = cmd.cmd,
    args = args,
    on_exit = function(proc, err)
      schedule()
      local out = vim.trim(proc:out() .. "\n" .. proc:err())
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

return M
