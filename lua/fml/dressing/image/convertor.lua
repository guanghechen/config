local __module_name__ = "fml.dressing.image.convertor" ---@type string

local env = require("eve.std.env")
local Spawn = require("eve.collection.spawn")
local config = require("fml.dressing.image.config")
local terminal = require("fml.dressing.image.terminal")
local util = require("fml.dressing.image.util")

---@class fml.dressing.image.convertor
local M = {}

---@class fml.dressing.image.Info
---@field public format                 string
---@field public size                   fml.dressing.image.Size
---@field public dpi                    fml.dressing.image.Size

---@class fml.dressing.image.convertor.IOptions
---@field public src                    string
---@field public on_done                ?fun(convert: fml.dressing.image.Convertor)

---@class fml.dressing.image.meta
---@field src string
---@field info? fml.dressing.image.Info
---@field [string] string|number|boolean

---@alias fml.dressing.image.args (number|string)[] | fun(): ((number|string)[])

---@class fml.dressing.image.Proc
---@field public cmd                    string
---@field public cwd                    string|nil
---@field public args                   fml.dressing.image.args

---@class fml.dressing.image.step
---@field public name                   string
---@field public file                   string
---@field public ft                     string
---@field public cmd                    fml.dressing.image.cmd
---@field public meta                   fml.dressing.image.meta
---@field public done                   ?boolean
---@field public err                    ?string
---@field public proc                   ?eve.collection.spawn.Proc

---@class fml.dressing.image.cmd
---@field public cmd                    (fun(step: fml.dressing.image.step): (fml.dressing.image.Proc|fml.dressing.image.Proc[])) | fml.dressing.image.Proc | fml.dressing.image.Proc[]
---@field public ft                     ?string
---@field public file                   ?fun(convertor: fml.dressing.image.Convertor, meta: fml.dressing.image.meta): string
---@field public depends                ?string[]
---@field public on_done                ?fun(step: fml.dressing.image.step)
---@field public on_error               ?fun(step: fml.dressing.image.step):boolean? when return true, continue to next step
---@field public pipe                   ?boolean

---@type table<string, fml.dressing.image.cmd>
local commands = {
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
      ctx.pdf = config.state.cache .. "/" .. vim.fs.basename(ctx.src):gsub("%.tex$", ".pdf")
      return convert:tmpfile("pdf")
    end,
    cmd = {
      {
        cwd = "{dirname}",
        cmd = "tectonic",
        args = { "-Z", "continue-on-errors", "--outdir", "{cache}", "{src}" },
      },
      {
        cmd = "pdflatex",
        cwd = "{dirname}",
        args = { "-output-directory={cache}", "-interaction=nonstopmode", "{src}" },
      },
    },
    on_done = function(step)
      local pdf = assert(step.meta.pdf, "No pdf file") --[[@as string]]
      if vim.uv.fs_stat(pdf) then
        vim.uv.fs_rename(pdf, step.file)
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
      args = config.state.convert.mermaid,
    },
    file = function(convertor)
      return convertor:tmpfile(vim.o.background .. ".png")
    end,
  },
  identify = {
    pipe = false,
    file = function(convertor)
      return convertor:tmpfile(convertor:ft() .. ".info")
    end,
    cmd = {
      {
        cmd = "magick",
        args = { "identify", "-format", "%m %[fx:w]x%[fx:h] %xx%y", "{src}[0]" },
      },
      {
        cmd = "identify",
        args = { "-format", "%m %[fx:w]x%[fx:h] %xx%y", "{src}[0]" },
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
  convert = {
    ft = "png",
    cmd = function(step)
      local formats = vim.deepcopy(config.state.convert.magick or {})
      local args = formats.default or { "{src}[0]" }
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
        not env.IS_WIN and { cmd = "convert", args = args } or nil,
      }
    end,
  },
}

local have = {} ---@type table<string, boolean>
local proc_queue = {} ---@type fml.dressing.image.Proc[]
local proc_running = 0 ---@type number
local MAX_PROCS = 3

---@param proc                          ?eve.collection.spawn.Proc
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

---@param step                          fml.dressing.image.step
---@return nil
local function get_cmd(step)
  local cmd = step.cmd.cmd
  cmd = type(cmd) == "function" and cmd(step) or cmd
  local cmds = cmd.cmd and { cmd } or cmd
  ---@cast cmds fml.dressing.image.Proc[]

  for _, c in ipairs(cmds) do
    if have[c.cmd] == nil then
      have[c.cmd] = vim.fn.executable(c.cmd) == 1
    end
    if have[c.cmd] then
      return c
    end
  end
end

---@class fml.dressing.image.Convertor
---@field opts                          fml.dressing.image.convertor.IOptions
---@field src                           string
---@field filepath                      string
---@field prefix                        string
---@field meta                          fml.dressing.image.meta
---@field steps                         fml.dressing.image.step[]
---@field _done                         ?boolean
---@field _err                          ?string
---@field _step                         integer
---@field tpl_data                      table<string, string>
local Convertor = {}
Convertor.__index = Convertor

---@param opts fml.dressing.image.convertor.IOptions
function Convertor.new(opts)
  vim.fn.mkdir(config.state.cache, "p")
  local self = setmetatable({}, Convertor)
  opts.src = M.norm(opts.src)
  self.opts = opts
  self.src = opts.src
  self._step = 0
  local base = vim.fn.fnamemodify(opts.src, ":t:r")
  if M.is_uri(self.opts.src) then
    base = self.opts.src:gsub("%?.*", ""):match("^%w%w+://(.*)$") or base
  end
  self.prefix = vim.fn.sha256(self.opts.src):sub(1, 8) .. "-" .. base:gsub("[^%w%.]+", "-")
  self.meta = { src = opts.src }
  self.steps = {}
  self.tpl_data = {
    cache = config.state.cache,
    bg = vim.o.background,
    scale = tostring(terminal.size().scale or 1),
  }
  self:resolve()
  return self
end

---@return fml.dressing.image.step|nil
function Convertor:current()
  return self.steps[self._step]
end

function Convertor:ready()
  return self:done() and not self:error()
end

function Convertor:done()
  return self._done or false
end

function Convertor:error()
  return self._err
end

---@param ft string
function Convertor:tmpfile(ft)
  return config.state.cache .. "/" .. self.prefix .. "." .. ft
end

---@param target string
function Convertor:_resolve(target)
  local cmd = assert(commands[target], "No command for target: " .. target)
  assert(cmd.file or cmd.ft, "No file or ft for target: " .. target)
  for _, dep in ipairs(cmd.depends or {}) do
    self:_resolve(dep)
  end
  local file = cmd.file and cmd.file(self, self.meta) or self:tmpfile(cmd.ft)
  ---@type fml.dressing.image.step
  local step = {
    name = target,
    file = file,
    ft = self:ft(file),
    meta = self.meta,
    done = vim.uv.fs_stat(file) ~= nil,
    cmd = cmd,
  }
  if cmd.pipe ~= false then
    self.meta = setmetatable({ src = file }, { __index = self.meta })
  end
  table.insert(self.steps, step)
end

---@param src? string
---@return string
function Convertor:ft(src)
  return vim.fn.fnamemodify(src or self.meta.src, ":e"):lower()
end

function Convertor:resolve()
  if M.is_uri(self.src) then
    self:_resolve("url")
    self:_resolve("identify")
  end
  while self:ft() ~= "png" do
    local ft = self:ft()
    local target = commands[ft] and ft or "convert"
    if self:_resolve(target) then
      break
    end
  end
  self:_resolve("identify")
  self.filepath = self.meta.src
end

---@param err                           ?string
---@return nil
function Convertor:on_step(err)
  local step = assert(self:current(), "No current step")
  step.done = true
  step.err = err
  if self.aborted then
    return self:on_done()
  end
  if step and err and step.cmd.on_error and step.cmd.on_error(step) then
    -- keep going
  elseif err then
    self._err = err
    return self:on_done()
  end
  if step and step.cmd.on_done then
    step.cmd.on_done(step)
  end

  if self._step < #self.steps then
    self:step()
  else
    self:on_done()
  end
end

-- Called when all steps are done or when an error occurs
function Convertor:on_done()
  local step = self:current()
  self._done = true
  if self._err then
    local title = step and ("Conversion failed at step `%s`"):format(step.name) or "Conversion failed"
    if step and step.proc then
      step.proc:debug({ title = title })
    else
      eve.std.reporter.error({
        from = __module_name__,
        subject = title,
        message = self._err,
      })
    end
  end
  if self.opts.on_done then
    self.opts.on_done(self)
  end
end

function Convertor:abort()
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

function Convertor:step()
  self._step = self._step + 1
  assert(self._step <= #self.steps, "No more steps")

  local step = self.steps[self._step]
  step.done = step.done or (vim.uv.fs_stat(step.file) ~= nil)
  if step.done then
    return self:on_step()
  end

  local cmd = get_cmd(step)
  if not cmd then
    return self:on_step("No command available")
  end

  local args = type(cmd.args) == "function" and cmd.args() or cmd.args
  ---@cast args (number|string)[]
  args = vim.deepcopy(args)

  local data = vim.tbl_extend("keep", {
    file = step.file,
    basename = vim.fs.basename(step.file),
    name = vim.fn.fnamemodify(step.file, ":t:r"),
    dirname = vim.fs.dirname(step.meta.src),
    src = step.meta.src,
  }, self.tpl_data)

  for a, arg in ipairs(args) do
    if type(arg) == "string" then
      args[a] = util.tpl(arg, data)
    end
  end

  step.proc = Spawn.new({
    run = false,
    debug = config.state.debug.convert,
    cwd = cmd.cwd and util.tpl(cmd.cwd, data) or nil,
    cmd = cmd.cmd,
    args = args,
    on_exit = function(proc, err)
      schedule()
      local out = vim.trim(proc:out() .. "\n" .. proc:err())
      vim.schedule(function()
        self:on_step(err and out or nil)
      end)
    end,
  })
  schedule(step.proc)
end

function Convertor:run()
  if #self.steps == 0 then
    return self:on_done()
  end

  if not M.is_uri(self.src) and vim.fn.filereadable(self.src) == 0 then
    local f = M.is_uri(self.src) and self.src or vim.fn.fnamemodify(self.src, ":p:~")
    self._err = ("File not found\n- `%s`"):format(f)
    return self:on_done()
  end

  self:step()
end
---@param src                           string
---@return boolean
function M.is_uri(src)
  return src:find("^%w%w+://") == 1
end

---@param src                           string
---@return string
function M.norm(src)
  if src:find("^file://") then
    src = vim.uri_to_fname(src)
  end
  if not M.is_uri(src) then
    src = vim.fs.normalize(vim.fn.fnamemodify(src, ":p"))
  end
  return src
end

---@param opts                          fml.dressing.image.convertor.IOptions
---@return fml.dressing.image.Convertor
function M.convert(opts)
  return Convertor.new(opts)
end

return M
