---@class fml.types.collection.IFrecency
---@field public access                 fun(self: fml.types.collection.IFrecency, key: string): nil
---@field public load                   fun(self: fml.types.collection.IFrecency, data: fml.types.collection.frecency.ISerializedData): nil
---@field public dump                   fun(self: fml.types.collection.IFrecency): fml.types.collection.frecency.ISerializedData
---@field public score                  fun(self: fml.types.collection.IFrecency, key: string): number

---@class fml.types.collection.frecency.IItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class fml.types.collection.frecency.ISerializedData
---@field public items                  fml.types.collection.frecency.IItem[]
