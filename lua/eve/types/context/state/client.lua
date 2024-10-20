---@class t.eve.context.state.theme
---@field public theme                  t.eve.collection.IObservable
---@field public mode                   t.eve.collection.IObservable
---@field public transparency           t.eve.collection.IObservable
---@field public relativenumber         t.eve.collection.IObservable
---@field public auto_integration       t.eve.collection.IObservable

---@class t.eve.context.client.state
---@field public theme                  t.eve.context.state.theme

---@class t.eve.context.client
---@field public state                  t.eve.context.client.state
---@field public dump                   fun(): t.eve.context.client.data
---@field public load                   fun(data: t.eve.context.client.data): nil
---@field public normalize              fun(data: any): t.eve.context.client.data
---@field public equals                 fun(data: t.eve.context.client.data): boolean
