local context_filepath = fc.path.locate_context_filepath({ filename = "client.json" }) ---@type string

---@class ghc.context.client : ghc.types.context.client
local M = fc.c.Viewmodel.new({
  name = "context:client",
  filepath = context_filepath,
  verbose = true,
})

return M
