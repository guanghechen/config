---@class ghc.context.session : eve.collection.Viewmodel
local M = require("ghc.context.session.mod")

require("ghc.context.session.find")
require("ghc.context.session.flight")
require("ghc.context.session.search")

M:load({ silent_on_notfound = true })

return M
