---@class t.eve.collection.ICircularStack
---@field public capacity               fun(self: t.eve.collection.ICircularStack): integer
---@field public size                   fun(self: t.eve.collection.ICircularStack): integer
---@field public at                     fun(self: t.eve.collection.ICircularStack, index: integer): t.eve.T|nil
---@field public clear                  fun(self: t.eve.collection.ICircularStack): nil
---@field public collect                fun(self: t.eve.collection.ICircularStack): t.eve.T[]
---@field public count                  fun(self: t.eve.collection.ICircularStack, filter: t.eve.IFilter): integer
---@field public fork                   fun(self: t.eve.collection.ICircularStack, filter: t.eve.IFilter): t.eve.collection.ICircularStack
---@field public iterator               fun(self: t.eve.collection.ICircularStack): fun(): t.eve.T|nil
---@field public iterator_reverse       fun(self: t.eve.collection.ICircularStack): fun(): t.eve.T|nil
---@field public pop                    fun(self: t.eve.collection.ICircularStack): t.eve.T|nil
---@field public push                   fun(self: t.eve.collection.ICircularStack, element: t.eve.T): nil
---@field public rearrange              fun(self: t.eve.collection.ICircularStack, filter: t.eve.IFilter): fun(): t.eve.T|nil
---@field public reset                  fun(self: t.eve.collection.ICircularStack, elements: t.eve.T[]): boolean): fun(): t.eve.T|nil
---@field public top                    fun(self: t.eve.collection.ICircularStack): t.eve.T|nil
---@field public update                 fun(self: t.eve.collection.ICircularStack, index: integer, value: t.eve.T): nil
