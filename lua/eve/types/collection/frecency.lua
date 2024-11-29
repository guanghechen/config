---@class eve.t.collection.IFrecency
---@field public access                 fun(self: eve.t.collection.IFrecency, key: string): nil
---@field public load                   fun(self: eve.t.collection.IFrecency, data: eve.t.collection.frecency.ISerializedData): nil
---@field public dump                   fun(self: eve.t.collection.IFrecency): eve.t.collection.frecency.ISerializedData
---@field public score                  fun(self: eve.t.collection.IFrecency, key: string): number

---@class eve.t.collection.frecency.IItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class eve.t.collection.frecency.ISerializedData
---@field public items                  eve.t.collection.frecency.IItem[]
