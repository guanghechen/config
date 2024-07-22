---@type string|nil
local filepath = fml.path.is_git_repo() and fml.path.locate_session_filepath({ filename = "session.json" }) or nil

---@class ghc.context.session : fml.collection.Viewmodel
local M = fml.collection.Viewmodel.new({
  name = "context:session",
  filepath = filepath,
})

return M
