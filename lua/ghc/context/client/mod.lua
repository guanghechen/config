local context_filepath = eve.path.locate_context_filepath({ filename = "client.json" }) ---@type string

---@class ghc.context.client : ghc.types.context.client
local M = eve.c.Viewmodel.new({
  name = "context:client",
  filepath = context_filepath,
  verbose = true,
})

eve.mvc.add_disposable(M)

return M
