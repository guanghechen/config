---@alias dot.module.explorer.NodeTypeEnum
---| "F"
---| "D"

---@alias dot.module.explorer.SelectModeEnum
---| "select"
---| "cut"
---| "copy"

---@alias dot.module.explorer.ForceExpandedEnum
---| "expand"
---| "collapse"

---@alias dot.module.explorer.ForceSelectedEnum
---| "select"
---| "unselect"

----------------------------------------------------------------------------------------------------
--- Resource
----------------------------------------------------------------------------------------------------

---@class dot.module.explorer.resource.INode
---@field public uri                    string
---@field public nodetype               dot.module.explorer.NodeTypeEnum
---@field public nodename               string

---@class dot.module.explorer.resource.IManager
---@field public compare                fun(left: dot.module.explorer.resource.INode, right: dot.module.explorer.resource.INode): integer
---@field public create                 fun(self: dot.module.explorer.resource.IManager, uri: string): dot.module.explorer.resource.INode|nil
---@field public copy                   fun(self: dot.module.explorer.resource.IManager, source_uri: string, target_uri: string): boolean
---@field public insert_if_missing      fun(self: dot.module.explorer.resource.IManager, uri: string): boolean
---@field public load                   fun(self: dot.module.explorer.resource.IManager, uri: string): dot.module.explorer.resource.INode[]
---@field public locate                 fun(self: dot.module.explorer.resource.IManager, uri: string): dot.module.explorer.resource.INode|nil
---@field public move                   fun(self: dot.module.explorer.resource.IManager, source_uri: string, target_uri: string): boolean
---@field public remove                 fun(self: dot.module.explorer.resource.IManager, uri: string, on_removed: fun(): nil): boolean

----------------------------------------------------------------------------------------------------
--- Node
----------------------------------------------------------------------------------------------------

---@class dot.module.explorer.node.IRootState
---@field public tick_expanded          integer
---@field public tick_selected          integer

---@class dot.module.explorer.node.INodeState
---@field public tick_expanded          integer
---@field public tick_loaded            integer

----------------------------------------------------------------------------------------------------
--- Tree
----------------------------------------------------------------------------------------------------

---@alias dot.module.explorer.ITreeTraverseCallback
---| fun(params: dot.module.explorer.ITreeTraverseCallbackParams): nil

---@class dot.module.explorer.ITreeTraverseCallbackParams
---@field public node                   dot.module.explorer.Node
---@field public depth                  integer
---@field public childindex             integer
---@field public indent                 string
