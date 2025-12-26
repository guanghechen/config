---@alias dot.module.explorer.ForceExpandedEnum
---| "expand"
---| "collapse"

---@alias dot.module.explorer.ForceSelectedEnum
---| "select"
---| "unselect"

---@alias dot.module.explorer.ITreeTraverseCallback
---| fun(params: dot.module.explorer.ITreeTraverseCallbackParams): nil

---@class dot.module.explorer.ITreeTraverseCallbackParams
---@field public node                   dot.module.explorer.Node
---@field public childindex             integer
---@field public depth                  integer
---@field public indent                 string

---@alias dot.module.explorer.NodeTypeEnum
---| "F"
---| "D"

---@alias dot.module.explorer.SelectModeEnum
---| "select"
---| "cut"
---| "copy"

---@class dot.module.explorer.action.IContext
---@field public widget                 dot.module.explorer.Widget
---@field public tree                   dot.module.explorer.Tree
---@field public resource_manager       dot.module.explorer.resource.FileManager
---@field public fullname               string
---@field public get_cursor_uri         fun(): string|nil
---@field public get_parent_uri         fun(uri: string): string
---@field public get_visual_nodes       fun(): dot.module.explorer.Node[]
---@field public refresh                fun(skip_refresh: boolean|nil): nil
---@field public render                 fun(): nil
---@field public sync_cursor_to_uri     fun(uri: string): nil

---@class dot.module.explorer.resource.IManager
---@field public compare                fun(left: dot.module.explorer.resource.INode, right: dot.module.explorer.resource.INode): integer
---@field public copy                   fun(self: dot.module.explorer.resource.IManager, source_uri: string, target_uri: string): boolean
---@field public create                 fun(self: dot.module.explorer.resource.IManager, uri: string): dot.module.explorer.resource.INode|nil
---@field public insert_if_missing      fun(self: dot.module.explorer.resource.IManager, uri: string): boolean
---@field public load                   fun(self: dot.module.explorer.resource.IManager, uri: string): dot.module.explorer.resource.INode[]
---@field public locate                 fun(self: dot.module.explorer.resource.IManager, uri: string): dot.module.explorer.resource.INode|nil
---@field public move                   fun(self: dot.module.explorer.resource.IManager, source_uri: string, target_uri: string): boolean
---@field public remove                 fun(self: dot.module.explorer.resource.IManager, uri: string, on_removed: fun(): nil): boolean

---@class dot.module.explorer.resource.INode
---@field public uri                    string
---@field public nodename               string
---@field public nodetype               dot.module.explorer.NodeTypeEnum
