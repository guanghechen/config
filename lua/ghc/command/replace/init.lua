local Disposable = fml.collection.Disposable
local BatchDisposable = fml.collection.BatchDisposable
local main = require("ghc.command.replace.main")
local state = require("ghc.command.replace.state")

---@class ghc.command.replace.IOpenParams
---@field public mode                   ?ghc.enums.command.replace.Mode
---@field public force                  ?boolean

---@class ghc.command.replace.ISearchParams
---@field public cwd                    ?string
---@field public word                   ?string

---@class ghc.command.replace.IReplaceParams
---@field public cwd                    ?string
---@field public word                   ?string

---@class ghc.command.replace
local M = {}

local batch_disposable = BatchDisposable.new()

---@type fml.types.collection.IUnsubscribable
local unsubscribable_1 = state.watch_search_changes(function()
  local bufnr_main = main.locate_main_buf() ---@type integer|nil
  if bufnr_main and fml.api.buf.is_visible(bufnr_main) then
    M.open()
  end
end)
batch_disposable:add_disposable(Disposable.from_unsubscribable(unsubscribable_1))

---@type fml.types.collection.IUnsubscribable
local unsubscribable_2 = state.watch_replace_changes(function()
  local bufnr_main = main.locate_main_buf() ---@type integer|nil
  if bufnr_main and fml.api.buf.is_visible(bufnr_main) then
    M.open()
  end
end)
batch_disposable:add_disposable(Disposable.from_unsubscribable(unsubscribable_2))

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

---@param params                        ?ghc.command.replace.IOpenParams
---@return nil
function M.open(params)
  params = params or {}
  local mode = params.mode ---@type ghc.enums.command.replace.Mode|nil
  local force = not not params.force ---@type boolean

  local tabnr = fml.api.tab.create_if_nonexist(fml.constant.TN_SEARCH_REPLACE) ---@type integer
  local winnr = main.locate_main_win(tabnr) ---@type integer

  state.set_mode(mode)
  main.render({ winnr = winnr, force = force })
end

return M
