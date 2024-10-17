local lsp_msg = eve.c.Observable.from_value("")

---@class ghc.context.transient : eve.collection.Viewmodel
---@field public lsp_msg                eve.types.collection.IObservable
local M = eve.c.Viewmodel.new({ name = "context:transient", save_on_dispose = false })
eve.mvc.add_disposable(M)

M --
  :register("lsp_msg", lsp_msg, true, false)

return M
