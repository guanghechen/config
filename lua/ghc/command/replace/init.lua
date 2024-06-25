local Replacer = require("ghc.command.replace.replacer")
local context_replace = require("ghc.context.replace")

---@class ghc.command.replace
local M = {}

local function get_state_from_context()
  return {
    mode = context_replace.mode:get_snapshot(),
    cwd = context_replace.cwd:get_snapshot(),
    flag_regex = context_replace.flag_regex:get_snapshot(),
    flag_case_sensitive = context_replace.flag_case_sensitive:get_snapshot(),
    search_pattern = context_replace.search_pattern:get_snapshot(),
    replace_pattern = context_replace.replace_pattern:get_snapshot(),
    search_paths = context_replace.search_paths:get_snapshot(),
    include_patterns = context_replace.include_patterns:get_snapshot(),
    exclude_patterns = context_replace.exclude_patterns:get_snapshot(),
  }
end

---@type ghc.command.replace.Replacer
M.Replacer = require("ghc.command.replace.replacer")

local replacer = Replacer.new({
  winnr = 0,
  reuse = true,
  data = get_state_from_context(),
  on_changed = function(s)
    local next_data = s:get_data() ---@type ghc.types.command.replace.IStateData
    context_replace.mode:next(next_data.mode)
    context_replace.cwd:next(next_data.cwd)
    context_replace.flag_regex:next(next_data.flag_regex)
    context_replace.flag_case_sensitive:next(next_data.flag_case_sensitive)
    context_replace.search_pattern:next(next_data.search_pattern)
    context_replace.replace_pattern:next(next_data.replace_pattern)
    context_replace.search_paths:next(next_data.search_paths)
    context_replace.include_patterns:next(next_data.include_patterns)
    context_replace.exclude_patterns:next(next_data.exclude_patterns)
  end,
})

fml.fn.watch_observables({
  context_replace.mode,
  context_replace.cwd,
  context_replace.flag_regex,
  context_replace.flag_case_sensitive,
  context_replace.search_pattern,
  context_replace.replace_pattern,
  context_replace.search_paths,
  context_replace.include_patterns,
  context_replace.exclude_patterns,
}, function()
  local next_data = get_state_from_context() ---@type ghc.types.command.replace.IStateData
  replacer.state:set_data(next_data)
end)

---@return nil
function M.search()
  replacer:open({ mode = "search" })
end

---@return nil
function M.replace()
  replacer:open({ mode = "replace" })
end

---@return nil
function M.open()
  replacer:open()
end

return M
