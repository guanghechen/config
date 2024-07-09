local Replacer = require("ghc.command.replace.replacer")

local _replacer = nil ---@type ghc.command.replace.Replacer|nil
---@return ghc.command.replace.Replacer
local function get_replacer()
  if _replacer == nil then
    _replacer = Replacer.new({ winnr = 0, reuse = true })
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
