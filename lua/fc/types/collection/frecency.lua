---@class fc.types.collection.IFrecency
---@field public access                 fun(self: fc.types.collection.IFrecency, key: string): nil
---@field public load                   fun(self: fc.types.collection.IFrecency, data: fc.types.collection.frecency.ISerializedData): nil
---@field public dump                   fun(self: fc.types.collection.IFrecency): fc.types.collection.frecency.ISerializedData
---@field public score                  fun(self: fc.types.collection.IFrecency, key: string): number

---@class fc.types.collection.frecency.IItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class fc.types.collection.frecency.ISerializedData
---@field public items                  fc.types.collection.frecency.IItem[]
