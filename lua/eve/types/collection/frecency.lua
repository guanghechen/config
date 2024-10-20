---@class t.eve.collection.IFrecency
---@field public access                 fun(self: t.eve.collection.IFrecency, key: string): nil
---@field public load                   fun(self: t.eve.collection.IFrecency, data: t.eve.collection.frecency.ISerializedData): nil
---@field public dump                   fun(self: t.eve.collection.IFrecency): t.eve.collection.frecency.ISerializedData
---@field public score                  fun(self: t.eve.collection.IFrecency, key: string): number

---@class t.eve.collection.frecency.IItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class t.eve.collection.frecency.ISerializedData
---@field public items                  t.eve.collection.frecency.IItem[]
