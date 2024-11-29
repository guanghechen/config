
---@class eve.t.context.data.theme
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public relativenumber         boolean

---@class eve.t.context.state.theme
---@field public theme                  eve.t.collection.IObservable
---@field public transparency           eve.t.collection.IObservable
---@field public relativenumber         eve.t.collection.IObservable

---@class eve.t.context.editor.data
---@field public theme                  eve.t.context.data.theme

---@class eve.t.context.editor.state
---@field public theme                  eve.t.context.state.theme

---@class eve.t.context.editor
---@field public state                  eve.t.context.editor.state
---@field public dump                   fun(): eve.t.context.editor.data
---@field public load                   fun(data: eve.t.context.editor.data): nil
---@field public normalize              fun(data: any): eve.t.context.editor.data
---@field public equals                 fun(data: eve.t.context.editor.data): boolean
