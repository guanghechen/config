require("fml.autocmd.auto_change_dir")
require("fml.autocmd.auto_create_dirs")

local state = require("fml.api.state")

---Rebuild the fml.api.state
state.refresh()

require("fml.autocmd.buf")
require("fml.autocmd.tab")
require("fml.autocmd.win")
require("fml.autocmd.lsp")
