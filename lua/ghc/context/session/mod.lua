---@type string|nil
local filepath = eve.path.is_git_repo() and eve.path.locate_session_filepath({ filename = "session.json" }) or nil

---@class ghc.context.session : eve.collection.Viewmodel
local M = eve.c.Viewmodel.new({
  name = "context:session",
  filepath = filepath,
  save_on_dispose = true,
})

eve.mvc.add_disposable(M)

return M
