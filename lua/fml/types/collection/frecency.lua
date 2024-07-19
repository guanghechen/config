---@class fml.types.collection.IFrecencyItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class fml.types.collection.IFrecencyData
---@field public items                  fml.types.collection.IFrecencyItem[]

---@class fml.types.collection.IFrecency
---@field public access                 fun(self: fml.types.collection.IFrecency, uuid: string): nil
---@field public dump                   fun(self: fml.types.collection.IFrecency): fml.types.collection.IFrecencyData
---@field public load                   fun(self: fml.types.collection.IFrecency, data: fml.types.collection.IFrecencyData): nil
---@field public score                  fun(self: fml.types.collection.IFrecency, uuid: string): number
