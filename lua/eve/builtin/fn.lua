---@class eve.builtin.fn
local M = {}


----------------------------------------------------------------------------------------------------

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
        local inner = w:sub(2 + #(opts.prefix or ""), -2)
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
      lines[l] = line:sub(indent)
    end
  end
  return ret
end

----------------------------------------------------------------------------------------------------


--- Merges the values similar to vim.tbl_deep_extend with the **force** behavior,
--- but the values can be any type
---@generic T
---@param ... T
---@return T
function M.merge_config(...)
  local ret = select(1, ...)
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if M.is_dict_like(ret) and M.is_dict(value) then
      for k, v in pairs(value) do
        ret[k] = M.merge_config(ret[k], v)
      end
    elseif value ~= nil then
      ret = value
    end
  end
  return ret
end

return M
