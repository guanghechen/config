---@class eve.types.collection.IBatchHandler
---@field public cleanup                fun(self: eve.types.collection.IBatchHandler): nil
---@field public run                    fun(self: eve.types.collection.IBatchHandler, action: fun(): nil): nil
---@field public summary                fun(self: eve.types.collection.IBatchHandler, title: string): nil): nil