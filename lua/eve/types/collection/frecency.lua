---@class eve.types.collection.IFrecency
---@field public access                 fun(self: eve.types.collection.IFrecency, key: string): nil
---@field public load                   fun(self: eve.types.collection.IFrecency, data: eve.types.collection.frecency.ISerializedData): nil
---@field public dump                   fun(self: eve.types.collection.IFrecency): eve.types.collection.frecency.ISerializedData
---@field public score                  fun(self: eve.types.collection.IFrecency, key: string): number

---@class eve.types.collection.frecency.IItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class eve.types.collection.frecency.ISerializedData
---@field public items                  eve.types.collection.frecency.IItem[]
