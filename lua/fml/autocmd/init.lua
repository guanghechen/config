require("fml.autocmd.bootstrap")
require("fml.autocmd.tmux")

---Rebuild the fml.api.state
require("fml.api.state").refresh_all()

require("fml.autocmd.state")
require("fml.autocmd.lsp")

require("fml.autocmd.resize")
