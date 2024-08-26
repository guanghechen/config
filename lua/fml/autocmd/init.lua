require("fml.autocmd.bootstrap")

---Rebuild the fml.api.state
require("fml.api.state").refresh_all()

require("fml.autocmd.state")
require("fml.autocmd.lsp")
