---@alias eve.fn.rename
---| function(params: eve.fn.rename.IParams): nil

---@class eve.fn.rename.IParams
---@field from                          string
---@field to                            string

---@type eve.fn.rename
local function rename(params)
  local from = params.from ---@type string
  local to = params.to ---@type string
end

return rename
