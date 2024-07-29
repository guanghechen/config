require("fml.autocmd.bootstrap")
require("fml.autocmd.disposable")

---Rebuild the fml.api.state
require("fml.api.state").refresh_all()

require("fml.autocmd.buf")
require("fml.autocmd.tab")
require("fml.autocmd.win")
require("fml.autocmd.lsp")
