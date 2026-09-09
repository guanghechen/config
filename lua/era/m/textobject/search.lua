---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.search" ---@type string

local M = {}

---@param span                          era.m.textobject.ISpan
---@param other                         era.m.textobject.ISpan
---@return boolean
function M.covers(span, other)
  if span.from == span.to then
    return other.from == span.from and other.to == span.to
  end
  if other.from == other.to then
    return span.from <= other.from and other.from < span.to
  end
  return span.from <= other.from and other.to <= span.to
end

---@param candidate                     era.m.textobject.ISpan
---@param current                       era.m.textobject.ISpan|nil
---@param reference                     era.m.textobject.ISpan
---@return boolean
local function is_better(candidate, current, reference)
  if M.covers(reference, candidate) then
    return false
  end
  local covers = M.covers(candidate, reference) ---@type boolean
  local current_covers = current ~= nil and M.covers(current, reference) ---@type boolean
  if covers ~= current_covers then
    return covers
  end
  if covers then
    return current == nil or candidate.to - candidate.from < current.to - current.from
  end
  if candidate.from < reference.from or candidate.to < reference.to then
    return false
  end
  return current == nil
    or candidate.from < current.from
    or (candidate.from == current.from and candidate.to < current.to)
end

---@param candidates                    era.m.textobject.ICandidate[]
---@param reference                     era.m.textobject.ISpan
---@param bounds                        era.m.textobject.ISpan|nil
---@param kind                          era.m.textobject.Kind
---@return era.m.textobject.ICandidate|nil
local function best(candidates, reference, bounds, kind)
  local result = nil ---@type era.m.textobject.ICandidate|nil
  for _, candidate in ipairs(candidates) do
    local tied = result ~= nil and candidate.span.from == result.span.from and candidate.span.to == result.span.to
    if
      (bounds == nil or M.covers(bounds, candidate.span))
      and (
        is_better(candidate.span, result and result.span, reference)
        or (
          tied
          and is_better(
            kind == "i" and candidate.inner or candidate.outer,
            kind == "i" and result.inner or result.outer,
            reference
          )
        )
      )
    then
      result = candidate
    end
  end
  return result
end

---Fixed cover-or-next search. The reference lines take priority over the wider neighborhood.
---@param candidates                    era.m.textobject.ICandidate[]
---@param reference                     era.m.textobject.ISpan
---@param kind                          era.m.textobject.Kind
---@param count                         integer
---@param local_bounds                  era.m.textobject.ISpan|nil
---@return era.m.textobject.ISpan|nil
---@return string|nil
function M.find(candidates, reference, kind, count, local_bounds)
  local current = reference ---@type era.m.textobject.ISpan
  local bounds = local_bounds ---@type era.m.textobject.ISpan|nil
  local result = nil ---@type era.m.textobject.ICandidate|nil
  for _ = 1, count do
    result = best(candidates, current, bounds, kind)
    if result == nil and bounds ~= nil then
      bounds = nil
      result = best(candidates, current, nil, kind)
    end
    if result == nil then
      return nil, nil
    end
    current = result.span
  end
  if result == nil then
    return nil, nil
  end

  local selected = kind == "a" and result.outer or result.inner ---@type era.m.textobject.ISpan
  -- Repeated Visual selection grows out of an already selected inner range.
  if reference.from ~= reference.to and M.covers(reference, selected) then
    result = best(candidates, current, bounds, kind) or (bounds ~= nil and best(candidates, current, nil, kind) or nil)
    if result == nil then
      return nil, nil
    end
    selected = kind == "a" and result.outer or result.inner
    if M.covers(reference, selected) then
      return nil, nil
    end
  end
  return selected, result.vis_mode
end

return M
