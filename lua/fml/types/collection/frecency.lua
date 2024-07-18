---@class fml.types.collection.IFrecencyItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class fml.types.collection.IFrecency
---@field public access                 fun(uuid: string): nil
---@field public score                  fun(uuid: string): number
