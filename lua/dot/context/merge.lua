---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.context.merge" ---@type string

---Digests of a context state by module name, then field name.
---@alias dot.context.merge.Fingerprints table<string, table<string, string>>

---Merges the state of instances that share a workspace one field at a time: an instance writes back the fields it
---changed since it loaded them, and every other field keeps the value in the file.
---@class dot.context.merge
local M = {}

---@param data                          table<string, table<string, unknown>> Values by module name, then field name.
---@return dot.context.merge.Fingerprints
function M.fingerprints(data)
  local fingerprints = {} ---@type dot.context.merge.Fingerprints
  for name, fields in pairs(data) do
    local digests = {} ---@type table<string, string>
    for field, value in pairs(fields) do
      -- Sorted keys encode equal values alike, whatever order their tables were built in.
      digests[field] = yoz.fn.md5(vim.json.encode(value, { sort_keys = true }))
    end
    fingerprints[name] = digests
  end
  return fingerprints
end

---Whether any field of `current`, including one set or cleared since, differs from `baseline`.
---@param baseline                      dot.context.merge.Fingerprints
---@param current                       dot.context.merge.Fingerprints
---@return boolean
function M.changed(baseline, current)
  for name, digests in pairs(current) do
    local base = baseline[name] or {}
    for field, digest in pairs(digests) do
      if base[field] ~= digest then
        return true
      end
    end
    for field in pairs(base) do
      if digests[field] == nil then
        return true
      end
    end
  end
  return false
end

---The state to write. Each field `ours` changed since `baseline` keeps its own value, even when cleared; every other
---field takes its value in `disk`, where instances that saved since may have changed it. Without `disk`, it is `ours`.
---@param baseline                      dot.context.merge.Fingerprints
---@param current                       dot.context.merge.Fingerprints Fingerprints of `ours`.
---@param ours                          table<string, table<string, unknown>>
---@param disk                          table<string, table<string, unknown>>|nil Normalized like `ours`.
---@return table<string, table<string, unknown>>
function M.merge(baseline, current, ours, disk)
  if disk == nil then
    return ours
  end
  local merged = {} ---@type table<string, table<string, unknown>>
  for name, fields in pairs(ours) do
    local base, digests, theirs = baseline[name] or {}, current[name] or {}, disk[name] or {}
    local result = {} ---@type table<string, unknown>
    for _, source in ipairs({ fields, theirs }) do
      for field in pairs(source) do
        if digests[field] ~= base[field] then
          result[field] = fields[field]
        else
          result[field] = theirs[field]
        end
      end
    end
    merged[name] = result
  end
  return merged
end

return M
