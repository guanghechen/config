---@class fml.types.collection.ICircularQueue
---@field public size               fun(self: fml.types.collection.ICircularQueue): number
---@field public at                 fun(self: fml.types.collection.ICircularQueue, index: number): fml.types.T|nil
---@field public front              fun(self: fml.types.collection.ICircularQueue): fml.types.T|nil
---@field public back               fun(self: fml.types.collection.ICircularQueue): fml.types.T|nil
---@field public collect            fun(): fml.types.T[]
---@field public enqueue            fun(self: fml.types.collection.ICircularQueue, element: fml.types.T): nil
---@field public dequeue            fun(self: fml.types.collection.ICircularQueue): fml.types.T|nil
---@field public dequeue_back       fun(self: fml.types.collection.ICircularQueue): fml.types.T|nil
---@field public iterator           fun(self: fml.types.collection.ICircularQueue): fun(): fml.types.T|nil
---@field public iterator_reverse   fun(self: fml.types.collection.ICircularQueue): fun(): fml.types.T|nil
