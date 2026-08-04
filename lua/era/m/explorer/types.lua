---@alias era.m.explorer.ForceExpandedEnum
---| "expand"
---| "collapse"

---@alias era.m.explorer.ForceSelectedEnum
---| "select"
---| "unselect"

---@alias era.m.explorer.ITreeTraverseCallback
---| fun(params: era.m.explorer.ITreeTraverseCallbackParams): nil

---@alias era.m.explorer.NodeTypeEnum
---| "F"
---| "D"

---@alias era.m.explorer.TransferModeEnum
---| "move"
---| "copy"

---@class era.m.explorer.IPendingTransferSource
---@field public filepath               string
---@field public nodename               string
---@field public nodetype               era.m.explorer.NodeTypeEnum

---@class era.m.explorer.IPendingTransfer
---@field public mode                   era.m.explorer.TransferModeEnum
---@field public sources                era.m.explorer.IPendingTransferSource[]
---@field public source_filepaths       table<string, boolean>

---@class era.m.explorer.ITreeTicks
---@field public structure              integer

---@class era.m.explorer.ITreeTraverseCallbackParams
---@field public node                   era.m.explorer.Node
---@field public childindex             integer
---@field public depth                  integer
---@field public indent                 string

---@class era.m.explorer.action.IContext
---@field public widget                 era.m.explorer.Widget
---@field public tree                   era.m.explorer.Tree
---@field public resource_manager       era.m.explorer.resource.FileManager
---@field public fullname               string
---@field public get_cursor_filepath         fun(): string|nil
---@field public get_parent_filepath         fun(filepath: string): string
---@field public get_visual_nodes       fun(): era.m.explorer.Node[]
---@field public refresh                fun(skip_refresh: boolean|nil): nil
---@field public render                 fun(): nil
---@field public sync_cursor_to_filepath     fun(filepath: string): nil

---@class era.m.explorer.resource.IManager
---@field public compare                fun(left: era.m.explorer.resource.INode, right: era.m.explorer.resource.INode): integer
---@field public copy                   fun(self: era.m.explorer.resource.IManager, source_filepath: string, target_filepath: string): boolean
---@field public create                 fun(self: era.m.explorer.resource.IManager, filepath: string): era.m.explorer.resource.INode|nil
---@field public insert_if_missing      fun(self: era.m.explorer.resource.IManager, filepath: string): boolean
---@field public load                   fun(self: era.m.explorer.resource.IManager, filepath: string): era.m.explorer.resource.INode[]
---@field public locate                 fun(self: era.m.explorer.resource.IManager, filepath: string): era.m.explorer.resource.INode|nil
---@field public move                   fun(self: era.m.explorer.resource.IManager, source_filepath: string, target_filepath: string): boolean
---@field public remove                 fun(self: era.m.explorer.resource.IManager, filepath: string, on_removed: fun(): nil): boolean
---@field public resolve_root_alias     fun(self: era.m.explorer.resource.IManager, root_filepath: string, target_filepath: string): string|nil

---@class era.m.explorer.resource.INode
---@field public filepath                    string
---@field public nodename               string
---@field public nodetype               era.m.explorer.NodeTypeEnum

---@class era.m.explorer.view.IDiagCounts
---@field public error                  integer
---@field public hint                   integer
---@field public info                   integer
---@field public warn                   integer

---@class era.m.explorer.view.IDiagnosticInfo
---@field public highlights             stl.t.IHighlightInline[]
---@field public lnum                   integer
---@field public text                   string

---@class era.m.explorer.view.IGitStatusInfo
---@field public highlights             stl.t.IHighlightInline[]
---@field public lnum                   integer
---@field public text                   string

---@class era.m.explorer.view.IFileIconInfo
---@field public highlight              stl.t.IHighlight
---@field public icon                   string
---@field public is_ignored             boolean
---@field public lnum                   integer
---@field public name_highlight         stl.t.IHighlight
---@field public nodename               string

---@class era.m.explorer.view.IRenderContext
---@field public tree                   era.m.explorer.Tree
---@field public root                   era.m.explorer.Node
---@field public root_filepath               string
---@field public resource_manager       ?era.m.explorer.resource.IManager
---@field public diag_counts            table<string, era.m.explorer.view.IDiagCounts>
---@field public defer_file_icons       boolean
---@field public deferred_file_icons    era.m.explorer.view.IFileIconInfo[]
---@field public foldempty              boolean
---@field public only_selected          boolean
---@field public pending_transfer       era.m.explorer.IPendingTransfer|nil
---@field public show_diagnostics       boolean
---@field public show_git_status        boolean
---@field public show_icons             boolean

---@class era.m.explorer.view.IRenderOptions
---@field public defer_file_icons       ?boolean
---@field public foldempty              ?boolean
---@field public only_selected          ?boolean
---@field public pending_transfer       era.m.explorer.IPendingTransfer|nil
---@field public resource_manager       ?era.m.explorer.resource.IManager
---@field public show_diagnostics       ?boolean
---@field public show_git_status        ?boolean
---@field public show_icons             ?boolean

---@class era.m.explorer.view.IRenderResult
---@field public diag_by_lnum           table<integer, era.m.explorer.view.IDiagnosticInfo>
---@field public deferred_file_icons    era.m.explorer.view.IFileIconInfo[]
---@field public diagnostic_info_list   era.m.explorer.view.IDiagnosticInfo[]
---@field public git_by_lnum            table<integer, era.m.explorer.view.IGitStatusInfo>
---@field public git_status_list        era.m.explorer.view.IGitStatusInfo[]
---@field public highlights             stl.t.IHighlight[]
---@field public lines                  string[]
---@field public lnum_to_filepath            table<integer, string>
---@field public sign_by_lnum           table<integer, era.m.explorer.view.ISignInfo>
---@field public sign_info_list         era.m.explorer.view.ISignInfo[]
---@field public filepath_to_lnum            table<string, integer>

---@class era.m.explorer.view.ISignInfo
---@field public lnum                   integer
---@field public sign_hl_group          string
---@field public sign_text              string
