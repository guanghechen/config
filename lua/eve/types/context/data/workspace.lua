---@class t.eve.context.data.buf.IItem
---@field public bufnr                  integer
---@field public filename               string
---@field public filepath               string
---@field public pinned                 boolean

---@class t.eve.context.data.tab.IItem
---@field public tabnr                  integer
---@field public name                   string
---@field public bufnrs                 integer[]

---@class t.eve.context.data.win.IItem
---@field public winnr                  integer
---@field public filepath_history       t.eve.collection.history.ISerializedData

---@class t.eve.context.data.frecency
---@field public files                  t.eve.collection.frecency.ISerializedData

---@class t.eve.context.data.input_history
---@field public find_files             t.eve.collection.history.ISerializedData
---@field public search_in_files        t.eve.collection.history.ISerializedData

---@class t.eve.context.workspace.data
---@field public bufs                   t.eve.context.data.buf.IItem[]
---@field public tabs                   t.eve.context.data.tab.IItem[]
---@field public wins                   t.eve.context.data.win.IItem[]
---@field public frecency               t.eve.context.data.frecency
---@field public input_history          t.eve.context.data.input_history
---@field public tab_history            t.eve.collection.history.ISerializedData
