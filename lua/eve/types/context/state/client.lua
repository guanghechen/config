---@class eve.t.context.state.dressing
---@field public autopairs              eve.t.collection.IObservable
---@field public winsep                 eve.t.collection.IObservable

---@class eve.t.context.state.theme
---@field public theme                  eve.t.collection.IObservable
---@field public transparency           eve.t.collection.IObservable
---@field public relativenumber         eve.t.collection.IObservable

---@class eve.t.context.client.state
---@field public dressing               eve.t.context.state.dressing
---@field public theme                  eve.t.context.state.theme

---@class eve.t.context.client
---@field public state                  eve.t.context.client.state
---@field public dump                   fun(): eve.t.context.client.data
---@field public load                   fun(data: eve.t.context.client.data): nil
---@field public normalize              fun(data: any): eve.t.context.client.data
---@field public equals                 fun(data: eve.t.context.client.data): boolean
