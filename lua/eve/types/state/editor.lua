
---@class eve.t.state.data.theme
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public relativenumber         boolean

---@class eve.t.state.state.theme
---@field public theme                  eve.lib.collection.IObservable
---@field public transparency           eve.lib.collection.IObservable
---@field public relativenumber         eve.lib.collection.IObservable

---@class eve.t.state.editor.data
---@field public theme                  eve.t.state.data.theme

---@class eve.t.state.editor.state
---@field public theme                  eve.t.state.state.theme

---@class eve.t.state.editor
---@field public state                  eve.t.state.editor.state
---@field public dump                   fun(): eve.t.state.editor.data
---@field public load                   fun(data: eve.t.state.editor.data): nil
---@field public normalize              fun(data: any): eve.t.state.editor.data
---@field public equals                 fun(data: eve.t.state.editor.data): boolean
