local bit = require("bit")
local fn = require("eve.builtin.fn")
local config = require("fml.dressing.image.config")
local convertor = require("fml.dressing.image.convertor")
local terminal = require("fml.dressing.image.terminal")

---@class fml.dressing.image.Image
---@field public src                    string
---@field public filepath               string
---@field public id                     integer image id. unique per nvim instance and file
---@field public sent                   ?boolean image data is sent
---@field public placements             table<number, fml.dressing.image.Placement> image placements
---@field public augroup                integer
---@field public info                   ?fml.dressing.image.Info
---@field _convert                      ?fml.dressing.image.Convertor
local M = {}
M.__index = M

local NVIM_ID_BITS = 10 ---@type integer
local CHUNK_SIZE = 4096 ---@type integer
local _id = 30 ---@type integer
local _pid = 0 ---@type integer
local nvim_id = 0 ---@type integer
local images = {} ---@type table<string, fml.dressing.image.Image>

---@param src                           string
---@return fml.dressing.image.Image
function M.new(src)
  local self = setmetatable({}, M)

  self.src = src
  self.filepath = self:convert()
  if images[self.filepath] then
    return images[self.filepath]
  end
  images[self.filepath] = self

  _id = _id + 1
  -- generate a unique id for this nvim instance (10 bits)
  if nvim_id == 0 then
    local pid = vim.fn.getpid()
    nvim_id = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, NVIM_ID_BITS)), 0x3FF)
  end
  -- interleave the nvim id and the image id
  self.id = bit.bor(bit.lshift(nvim_id, 24 - NVIM_ID_BITS), _id)
  self.placements = {}
  self.augroup = fn.augroup("fml.dressing.image." .. self.id)

  self:run()
  if self:ready() then
    self:on_ready()
  end

  return self
end

---@return nil
function M:on_ready()
  if not self.sent then
    self.info = self._convert and self._convert.meta.info or nil
    self:send()
  end
end

---@return nil
function M:on_send()
  for _, placement in pairs(self.placements) do
    placement:update()
  end
end

---@return boolean
function M:failed()
  if self._convert and not self._convert:done() then
    return false
  end
  if self._convert and self._convert:error() then
    return true
  end
  return self.filepath and vim.fn.filereadable(self.filepath) == 0
end

---@return boolean
function M:ready()
  if self._convert and not self._convert:done() then
    return false
  end
  return self.filepath and vim.fn.filereadable(self.filepath) == 1
end

---@return nil
function M:run()
  if not self._convert then
    return
  end
  self._convert:run(function(convert)
    if convert:error() then
      vim.schedule(function()
        for _, p in pairs(self.placements) do
          p:error()
        end
      end)
    else
      vim.schedule(function()
        self:on_ready()
      end)
    end
  end)
end

---@return string
function M:convert()
  self._convert = convertor.convert({ src = self.src })
  return self._convert.file
end

-- create the image
---@return nil
function M:send()
  assert(not self.sent, "Image already sent")
  self.sent = true

  -- local image
  local env = config.resolve_env() ---@type fml.dressing.image.config.env
  if not env.remote then
    terminal.request({
      t = "f",
      i = self.id,
      f = 100,
      data = vim.base64.encode(self.filepath),
    })
  else
    -- remote image
    local fd = assert(io.open(self.filepath, "rb"), "Failed to open file: " .. self.filepath)
    local data = fd:read("*a")
    fd:close()
    data = vim.base64.encode(data) -- encode the data
    local offset = 1
    while offset <= #data do
      local chunk = data:sub(offset, offset + CHUNK_SIZE - 1)
      local first = offset == 1
      offset = offset + CHUNK_SIZE
      local last = offset > #data
      if first then
        terminal.request({
          t = "d",
          i = self.id,
          f = 100,
          m = last and 0 or 1,
          data = chunk,
        })
      else
        terminal.request({
          m = last and 0 or 1,
          data = chunk,
        })
      end
      vim.uv.sleep(1)
    end
  end
  self:on_send()
end

---@param placement                     fml.dressing.image.Placement
---@return nil
function M:place(placement)
  for pid, p in pairs(self.placements) do
    if p == placement then
      placement.id = pid
      return pid
    end
  end
  _pid = _pid + 1
  placement.id = _pid
  self.placements[_pid] = placement
end

---@param pid                           ?integer
---@return nil
function M:del(pid)
  local pids = pid and { pid } or vim.tbl_keys(self.placements) ---@type integer[]
  for index, p in ipairs(pids) do
    if self.placements[p] then
      terminal.request({ a = "d", d = "i", i = self.id, p = index })
      self.placements[p] = nil
    end
  end

  if not next(self.placements) then
    terminal.request({ a = "d", d = "i", i = self.id })
    self.sent = false
    pcall(vim.api.nvim_del_autocmd_by_id, self.augroup)
  end
end

return M
