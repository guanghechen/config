---@class fml.types.collection.IFrecencyItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class fml.types.collection.IFrecency
---@field public access                 fun(self: fml.types.collection.IFrecency, uuid: string): nil
---@field public score                  fun(self: fml.types.collection.IFrecency, uuid: string): number
