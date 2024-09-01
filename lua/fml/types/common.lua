---@class fml.types.IKeymapOverridable
---@field public bufnr                  ?integer
---@field public nowait                 ?boolean
---@field public noremap                ?boolean
---@field public silent                 ?boolean

---@class fml.types.IKeymap : fml.types.IKeymapOverridable
---@field public modes                  fc.enums.VimMode[]
---@field public key                    string
---@field public callback               fun(): nil
---@field public desc                   string|nil

---@class fml.types.IQuickFixItem
---@field public filename               string
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public text                   ?string
