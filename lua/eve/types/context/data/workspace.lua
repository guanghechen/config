---@class eve.t.context.data.buf.IItem
---@field public bufnr                  integer
---@field public filename               string
---@field public filepath               string
---@field public pinned                 boolean

---@class eve.t.context.data.tab.IItem
---@field public tabnr                  integer
---@field public name                   string
---@field public bufnrs                 integer[]

---@class eve.t.context.data.win.IItem
---@field public winnr                  integer
---@field public filepath_history       eve.t.collection.history.ISerializedData

---@class eve.t.context.data.frecency
---@field public files                  eve.t.collection.frecency.ISerializedData

---@class eve.t.context.data.input_history
---@field public find_files             eve.t.collection.history.ISerializedData
---@field public search_in_files        eve.t.collection.history.ISerializedData

---@class eve.t.context.workspace.data
---@field public bufs                   eve.t.context.data.buf.IItem[]
---@field public tabs                   eve.t.context.data.tab.IItem[]
---@field public wins                   eve.t.context.data.win.IItem[]
---@field public frecency               eve.t.context.data.frecency
---@field public input_history          eve.t.context.data.input_history
---@field public tab_history            eve.t.collection.history.ISerializedData
