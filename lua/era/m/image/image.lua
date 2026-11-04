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

local NVIM_ID_BITS = 10
local MAX_FSIZE = 200 * 1024 * 1024

---@type integer
local _id = 30

---@type integer
local nvim_id = 0

---The current version of each source, by source id.
---@type table<string, era.m.image.Image>
local images = {}

---@type {img: era.m.image.Image, used: integer}[]
local lru = {}

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
  _id = _id + 1
  local bit = require("bit")
  if nvim_id == 0 then
    local pid = vim.fn.getpid()
    nvim_id = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, NVIM_ID_BITS)), 0x3FF)
  end
  self.id = bit.bor(bit.lshift(nvim_id, 24 - NVIM_ID_BITS), _id)
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
  for id, p in ipairs(pid and { pid } or vim.tbl_keys(self.placements)) do
    if self.placements[p] then
      terminal.request({ a = "d", d = "i", i = self.id, p = id })
      self.placements[p] = nil
    end
  end

  if not next(self.placements) then
    if self.retired then
      self:__free__()
    else
      terminal.request({ a = "d", d = "i", i = self.id })
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
  local convert = require("era.m.image.convert")
  self.convert = convert.convert({ source = self.source })
  self.convert:future():finally(function(resolved, c)
    if not resolved then
      return
    end
    if c:error() then
      vim.schedule(function()
        for _, p in pairs(self.placements) do
          p:error()
        end
      end)
    else
      vim.schedule(function()
        self:__on_ready__()
      end)
    end
  end)
  return self.convert.file
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
  self.sent = true
  terminal.request({
    t = "f",
    i = self.id,
    f = 100,
    data = vim.base64.encode(self.file),
  })
  self:__on_send__()
end

---A newer version of the source replaced this image; it is freed once no placement shows it.
---@return nil
function M:__retire__()
  self.retired = true
  if not next(self.placements) then
    self:__free__()
  end
end

---Releases the image data held by the terminal and the conversion outputs of a retired image.
---@return nil
function M:__free__()
  for i, v in ipairs(lru) do
    if v.img == self then
      table.remove(lru, i)
      lru_fsize = lru_fsize - (self.fsize or 0)
      break
    end
  end
  if self.sent then
    self.sent = false
    require("era.m.image.terminal").request({ a = "d", d = "I", i = self.id })
  end
  if self.convert then
    self.convert:discard()
  end
end

return M
