local Replacer = require("ghc.command.replace.replacer")
local context = require("ghc.context.search")

local function get_state_from_context()
  return {
    mode = context.mode:get_snapshot(),
    cwd = context.cwd:get_snapshot(),
    flag_regex = context.flag_regex:get_snapshot(),
    flag_case_sensitive = context.flag_case_sensitive:get_snapshot(),
    search_pattern = context.search_pattern:get_snapshot(),
    replace_pattern = context.replace_pattern:get_snapshot(),
    search_paths = context.search_paths:get_snapshot(),
    include_patterns = context.include_patterns:get_snapshot(),
    exclude_patterns = context.exclude_patterns:get_snapshot(),
  }
end

---@class ghc.command.replace

local M = {}

---@class ghc.command.replace.ISearchParams
---@field public cwd                    ?string
---@field public word                   ?string

---@class ghc.command.replace.IReplaceParams
---@field public cwd                    ?string
---@field public word                   ?string

---@type ghc.command.replace.Replacer
M.Replacer = require("ghc.command.replace.replacer")

local replacer = Replacer.new({
  winnr = 0,
  reuse = true,
  data = get_state_from_context(),
  on_changed = function(s)
    local next_data = s:get_data() ---@type ghc.types.command.replace.IStateData
    context.mode:next(next_data.mode)
    context.cwd:next(next_data.cwd)
    context.flag_regex:next(next_data.flag_regex)
    context.flag_case_sensitive:next(next_data.flag_case_sensitive)
    context.search_pattern:next(next_data.search_pattern)
    context.replace_pattern:next(next_data.replace_pattern)
    context.search_paths:next(next_data.search_paths)
    context.include_patterns:next(next_data.include_patterns)
    context.exclude_patterns:next(next_data.exclude_patterns)
  end,
})

fml.fn.watch_observables({
  context.mode,
  context.cwd,
  context.flag_regex,
  context.flag_case_sensitive,
  context.search_pattern,
  context.replace_pattern,
  context.search_paths,
  context.include_patterns,
  context.exclude_patterns,
}, function()
  local next_data = get_state_from_context() ---@type ghc.types.command.replace.IStateData
  replacer.state:set_data(next_data)
end)

---@param params                        ?ghc.command.replace.ISearchParams
---@return nil
function M.search(params)
  params = params or {}
  if params.cwd then
    ghc.context.search.cwd:next(params.cwd)
  end
  if params.word then
    ghc.context.search.search_pattern:next(params.word)
  end
  replacer:open({ mode = "search" })
end

---@param params                        ?ghc.command.replace.IReplaceParams
---@return nil
function M.replace(params)
  params = params or {}
  if params.cwd then
    ghc.context.search.cwd:next(params.cwd)
  end
  if params.word then
    ghc.context.search.search_pattern:next(params.word)
  end
  replacer:open({ mode = "replace" })
end

---@return nil
function M.open()
  replacer:open()
end

return M
