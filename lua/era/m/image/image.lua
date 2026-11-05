---@class era.m.image.Image
---@field public src                      string
---@field public file                     string
---@field public id                       integer
---@field public sent                     ?boolean
---@field public placements               table<integer, era.m.image.Placement>
---@field public info                     ?era.m.image.Info
---@field public fsize                    ?integer
---@field public convert                  ?era.m.image.Convert
---@field public source                 era.m.image.convert.Source
---@field public retired                ?boolean
local M = {}
M.__index = M

local MAX_FSIZE = 200 * 1024 * 1024

---Ids in use, so that a random one is never handed out twice.
---@type table<integer, boolean>
local ids = {}

---The current version of each source, by source id.
---@type table<string, era.m.image.Image>
local images = {}

---@type {img: era.m.image.Image, used: integer}[]
local lru = {}

---A random id small enough for the 24-bit color that carries it to the terminal. All programs a terminal shows, every
---tmux pane included, share one image store, so ids counted per Neovim instance collide across instances.
---@return integer
local function new_id()
  while true do
    local high, middle, low = assert(vim.uv.random(3)):byte(1, 3)
    local id = high * 65536 + middle * 256 + low
    if id ~= 0 and not ids[id] then
      ids[id] = true
      return id
    end
  end
end

---@type integer
local lru_fsize = 0

---@param img                            era.m.image.Image
---@return nil
local function use(img)
  if img.fsize == 0 then
    return
  end
  local now = os.time()
  for _, v in ipairs(lru) do
    if v.img == img then
      v.used = now
      return
    end
  end
  table.sort(lru, function(a, b)
    return a.used > b.used
  end)
  while lru_fsize >= MAX_FSIZE and #lru > 0 do
    local i = table.remove(lru).img
    i.sent = false
    lru_fsize = lru_fsize - (i.fsize or 0)
  end
  lru_fsize = lru_fsize + (img.fsize or 0)
  table.insert(lru, { img = img, used = now })
end

---The color formulas are drawn in, as `RRGGBB`.
---@return string
local function math_color()
  local fg = vim.api.nvim_get_hl(0, { name = "m_img_math", link = false }).fg
  return ("%06X"):format(fg or 0)
end

---@param src                            string
---@return era.m.image.Image
function M.new(src)
  local source = require("era.m.image.convert").source(src)
  local current = images[source.id]
  if current and current.source.version == source.version then
    return current
  end
  local self = setmetatable({}, M)
  self.src = src
  self.source = source
  self.placements = {}
  self.file = self:__convert__()
  images[source.id] = self
  self.id = new_id()
  if current then
    current:__retire__()
  end

  self:run()
  if self:ready() then
    self:__on_ready__()
  end

  return self
end

---This image while its source is unchanged on disk, otherwise the image of the source's current version.
---@return era.m.image.Image
function M:latest()
  if require("era.m.image.convert").version(self.source.path) == self.source.version then
    return self
  end
  return M.new(self.src)
end

---The terminal lost the images it held, e.g. a tmux client attached from another terminal: each image is sent again
---the next time a placement shows it.
---@return nil
function M.resend()
  for _, entry in ipairs(lru) do
    entry.img.sent = false
  end
  for _, img in pairs(images) do
    img.sent = false
  end
  lru = {}
  lru_fsize = 0
end

---Draws the images placements show in the colors the theme gives them now. One still converting, or that nothing
---shows, takes them once it is sent.
---@return nil
function M.recolor()
  for _, img in pairs(images) do
    if next(img.placements) and img:ready() and img:__discolored__() then
      img:__recolor__()
    end
  end
end

---@return boolean
function M:failed()
  if self.convert and not self.convert:done() then
    return false
  end
  if self.convert and self.convert:error() then
    return true
  end
  return self.file and vim.fn.filereadable(self.file) == 0
end

---@return boolean
function M:ready()
  -- A failed conversion of a source that needs none leaves the readable source as its file.
  if self.convert and (not self.convert:done() or self.convert:error()) then
    return false
  end
  return self.file and vim.fn.filereadable(self.file) == 1
end

---@return nil
function M:run()
  if not self.convert then
    return
  end
  self.convert:run()
end

---@param placement                      era.m.image.Placement
---@return nil
function M:place(placement)
  assert(type(placement.id) == "number", "`Image:place`: placement.id should be a number")
  self.placements[placement.id] = placement
  if self.sent then
    use(self)
  elseif self:ready() then
    self:__send__()
  end
end

---@param pid                            ?integer
---@return nil
function M:del(pid)
  local terminal = require("era.m.image.terminal")
  for _, id in ipairs(pid and { pid } or vim.tbl_keys(self.placements)) do
    if self.placements[id] then
      terminal.request({ a = "d", d = "i", i = self.id, p = id })
      self.placements[id] = nil
    end
  end

  if not next(self.placements) then
    if self.retired then
      self:__free__()
    else
      self:__release__()
    end
  end
end

---@return nil
function M.clear()
  images = {}
end

----------------------------------------------------------------------------------------------------

---@return string
function M:__convert__()
  local conversion = require("era.m.image.convert").convert({ source = self.source, color = math_color() })
  self.convert = conversion
  conversion:future():finally(function(resolved)
    if not resolved then
      return
    end
    vim.schedule(function()
      -- `__recolor__` replaced it.
      if self.convert ~= conversion then
        return
      end
      if conversion:error() then
        for _, p in pairs(self.placements) do
          p:error()
        end
      else
        self:__on_ready__()
      end
    end)
  end)
  return conversion.file
end

---@return nil
function M:__on_ready__()
  -- A replaced version that nothing shows any more has been freed.
  if self.retired and not next(self.placements) then
    return
  end
  if not self.sent then
    self.fsize = vim.fn.getfsize(self.file)
    self.info = self.convert and self.convert.meta.info or nil
    if self.info and self.info.size then
      self.fsize = (self.info.size.width * 4 + 1) * self.info.size.height
    end
    self:__send__()
  end
end

---@return nil
function M:__on_send__()
  use(self)
  for _, placement in pairs(self.placements) do
    placement:update()
  end
end

---@return nil
function M:__send__()
  local terminal = require("era.m.image.terminal")
  assert(not self.sent, "Image already sent")
  if self:__discolored__() then
    return self:__recolor__()
  end
  self.sent = true
  terminal.request({
    t = "f",
    i = self.id,
    f = 100,
    data = vim.base64.encode(self.file),
  })
  self:__on_send__()
end

---Whether the theme has changed the colors of this image since it converted: of a formula its color, of a chart its
---background.
---@return boolean
function M:__discolored__()
  local c = self.convert
  if c == nil then
    return false
  end
  return (c.color ~= nil and c.color ~= math_color()) or (c.background ~= nil and c.background ~= vim.o.background)
end

---Converts a discolored image again, which for a formula runs only the step that colors it; once done, it is sent anew
---under its id, and its placements show the old colors until then.
---@return nil
function M:__recolor__()
  self.file = self:__convert__()
  self.sent = false
  self:run()
  if self:ready() then
    self:__on_ready__()
  end
end

---A newer version of the source replaced this image; it is freed once no placement shows it.
---@return nil
function M:__retire__()
  self.retired = true
  if not next(self.placements) then
    self:__free__()
  end
end

---Releases the image data the terminal holds once no placement shows the image; a placement showing it again sends it
---anew. Data `use` marked unsent for its budget is still held, so it goes as well.
---@return nil
function M:__release__()
  for i, v in ipairs(lru) do
    if v.img == self then
      table.remove(lru, i)
      lru_fsize = lru_fsize - (self.fsize or 0)
      break
    end
  end
  self.sent = false
  require("era.m.image.terminal").request({ a = "d", d = "I", i = self.id })
end

---Releases the image data held by the terminal and the conversion outputs of a retired image.
---@return nil
function M:__free__()
  self:__release__()
  ids[self.id] = nil
  if self.convert then
    self.convert:discard()
  end
end

return M
