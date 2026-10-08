---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.types" ---@type string

---@class era.m.explorer.IInputRange
---@field frame                         yoz.ux.treeview.Frame
---@field first                         integer
---@field last                          integer

---@class era.m.explorer.ICursorInput
---@field frame                         yoz.ux.treeview.Frame
---@field resource                      yoz.ux.filetree.Resource

---@alias era.m.explorer.JobKind "create"|"copy"|"move"|"paste"|"delete"|"rename"|"copy_to_path"|"move_to_path"|"copy_to_directory"|"move_to_directory"
---@alias era.m.explorer.OperationKind "create"|"copy"|"move"|"delete"|"trash"
---@alias era.m.explorer.OnJobComplete fun(status: ux.filetree.IJobStatus, results: era.m.explorer.IItemResult[]): nil

---@class era.m.explorer.IEditorSyncError
---@field message                       string First diagnostic, at most 4 KiB; additional failures are counted.
---@field failures                      integer

---@class era.m.explorer.IItemResult: ux.filetree.IItemResult
---@field editor_error                  ?era.m.explorer.IEditorSyncError

---@class era.m.explorer.IJobRequestBase
---@field on_complete                   ?era.m.explorer.OnJobComplete

---@class (exact) era.m.explorer.ITransferRequest: era.m.explorer.IJobRequestBase
---@field kind                          "copy"|"move"|"paste"
---@field target                        ?yoz.ux.filetree.Resource
---@field range                         ?era.m.explorer.IInputRange
---@field name                          ?string

---@class (exact) era.m.explorer.ICreateRequest: era.m.explorer.IJobRequestBase
---@field kind                          "create"
---@field target                        ?yoz.ux.filetree.Resource
---@field path                          ?ux.filetree.Path
---@field directory                     ?boolean

---@class (exact) era.m.explorer.IRenameRequest: era.m.explorer.IJobRequestBase
---@field kind                          "rename"
---@field name                          ?string

---@class (exact) era.m.explorer.IPathRequest: era.m.explorer.IJobRequestBase
---@field kind                          "copy_to_path"|"move_to_path"
---@field path                          ?ux.filetree.Path Prompt when omitted.
---@field default_path                  ?ux.filetree.Path
---@field cursor                        ?era.m.explorer.ICursorInput

---@class (exact) era.m.explorer.IDirectoryRequest: era.m.explorer.IJobRequestBase
---@field kind                          "copy_to_directory"|"move_to_directory"
---@field path                          ?ux.filetree.Path Prompt when omitted.

---@class (exact) era.m.explorer.IDeleteRequest: era.m.explorer.IJobRequestBase
---@field kind                          "delete"
---@field range                         ?era.m.explorer.IInputRange

---@alias era.m.explorer.IJobRequest era.m.explorer.ITransferRequest|era.m.explorer.ICreateRequest|era.m.explorer.IRenameRequest|era.m.explorer.IPathRequest|era.m.explorer.IDirectoryRequest|era.m.explorer.IDeleteRequest

---@class (exact) era.m.explorer.IPreparation
---@field cancelled                     boolean
---@field label                         string
---@field launched                      ?boolean
---@field resume                        ?fun(value: string|nil): nil
---@field job                           ?yoz.ux.filetree.Job

---@class era.m.explorer.IJobCounts
---@field success                       integer
---@field failed                        integer
---@field skipped                       integer
---@field editor_failed                 integer Items whose IO succeeded but editor synchronization did not complete.

---@class era.m.explorer.widget.IProps
---@field name                          string
---@field root                          ?ux.filetree.Path
---@field data                          ?ux.filetree.Data Share resources with an independent state.
---@field session                       ?era.m.explorer.Session Share complete interaction state and jobs.
---@field o_width                       ?stl.c.Observable
---@field o_flag_selected               ?stl.c.Observable
---@field o_flag_viewtype               ?stl.c.Observable
---@field o_flag_foldempty              ?stl.c.Observable
---@field o_flag_hidden                 ?stl.c.Observable
---@field on_disposed                   ?fun(): nil
