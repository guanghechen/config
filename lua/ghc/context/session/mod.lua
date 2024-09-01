---@type string|nil
local filepath = fc.path.is_git_repo() and fc.path.locate_session_filepath({ filename = "session.json" }) or nil

---@class ghc.context.session : fc.c.Viewmodel
local M = fc.c.Viewmodel.new({
  name = "context:session",
  filepath = filepath,
})

return M
