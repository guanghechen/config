local Replacer = require("ghc.command.replace.replacer")
local session = require("ghc.context.session")

local _replacer = nil ---@type ghc.command.replace.Replacer|nil
---@return ghc.command.replace.Replacer
local function get_replacer()
  if _replacer == nil then
    ---@return ghc.types.command.replace.IStateData
    local function get_state_from_context()
      return {
        mode = session.search_mode:get_snapshot(),
        cwd = session.search_cwd:get_snapshot(),
        flag_regex = session.search_flag_regex:get_snapshot(),
        flag_case_sensitive = session.search_flag_case_sensitive:get_snapshot(),
        search_pattern = session.search_pattern:get_snapshot(),
        replace_pattern = session.replace_pattern:get_snapshot(),
        search_paths = session.search_paths:get_snapshot(),
        include_patterns = session.search_include_patterns:get_snapshot(),
        exclude_patterns = session.search_exclude_patterns:get_snapshot(),
      }
    end

    _replacer = Replacer.new({
      winnr = 0,
      reuse = true,
      data = get_state_from_context(),
      on_changed = function(s)
        local next_data = s:get_data() ---@type ghc.types.command.replace.IStateData
        session.search_mode:next(next_data.mode)
        session.search_cwd:next(next_data.cwd)
        session.search_flag_regex:next(next_data.flag_regex)
        session.search_flag_case_sensitive:next(next_data.flag_case_sensitive)
        session.search_pattern:next(next_data.search_pattern)
        session.replace_pattern:next(next_data.replace_pattern)
        session.search_paths:next(next_data.search_paths)
        session.search_include_patterns:next(next_data.include_patterns)
        session.search_exclude_patterns:next(next_data.exclude_patterns)
      end,
    })

    fml.fn.watch_observables({
      session.search_mode,
      session.search_cwd,
      session.search_flag_regex,
      session.search_flag_case_sensitive,
      session.search_pattern,
      session.replace_pattern,
      session.search_paths,
      session.search_include_patterns,
      session.search_exclude_patterns,
    }, function()
      local next_data = get_state_from_context() ---@type ghc.types.command.replace.IStateData
      _replacer.state:set_data(next_data)
    end)
  end
  return _replacer
end

---@class ghc.command.replace
local M = {}

---@class ghc.command.replace.ISearchParams
---@field public cwd                    ?string
---@field public word                   ?string

---@class ghc.command.replace.IReplaceParams
---@field public cwd                    ?string
---@field public word                   ?string

---@param params                        ?ghc.command.replace.ISearchParams
---@return nil
function M.search(params)
  params = params or {}
  if params.cwd then
    ghc.context.session.search_cwd:next(params.cwd)
  end
  if params.word then
    ghc.context.session.search_pattern:next(params.word)
  end

  ghc.context.session.search_mode:next("search")
  M.open()
end

---@param params                        ?ghc.command.replace.IReplaceParams
---@return nil
function M.replace(params)
  params = params or {}
  if params.cwd then
    ghc.context.session.search_cwd:next(params.cwd)
  end
  if params.word then
    ghc.context.session.search_pattern:next(params.word)
  end

  ghc.context.session.search_mode:next("replace")
  M.open()
end

---@return nil
function M.open()
  fml.api.tab.create_if_nonexist("replace")
  local replacer = get_replacer() ---@type ghc.command.replace.Replacer
  replacer:open()
end

return M
