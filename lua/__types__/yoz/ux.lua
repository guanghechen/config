---@meta

---@class yoz.ux
---@field public treeview               yoz.ux.treeview

---@class yoz.ux.treeview
local M = {}

---@param limits                        ?ux.treeview.ILimits
---@return yoz.ux.treeview.Data
function M.new_data(limits) end

---@class yoz.ux.treeview.Ticket
local Ticket = {}
---@return boolean done
---@return any result
function Ticket:poll() end

---@class yoz.ux.treeview.NodeIds
local NodeIds = {}
---@return integer
function NodeIds:len() end
---@param index                         integer
---@return ux.treeview.NodeId|nil
function NodeIds:get(index) end
---@param first                         integer
---@param last                          integer
---@return ux.treeview.NodeId[]
function NodeIds:slice(first, last) end

---@class yoz.ux.treeview.Source
local Source = {}
---@return ux.treeview.Revision
function Source:revision() end
---@param scope                         ux.treeview.IDataScope
---@return table|nil
function Source:query_result(scope) end
---@return integer
function Source:len() end
---@param key                           string
---@return ux.treeview.NodeId|nil
function Source:id(key) end
---@param node                          ux.treeview.NodeId
---@return ux.treeview.INode|nil
function Source:node(node) end
---@param node                          ?ux.treeview.NodeId
---@param first                         integer
---@param last                          integer
---@return ux.treeview.NodeId[]
function Source:children(node, first, last) end

---@class yoz.ux.treeview.Frame
local Frame = {}
---@return string
function Frame:id() end
---@return ux.treeview.IFrameHeader
function Frame:header() end
---@param row                           integer
---@return ux.treeview.NodeId|nil
function Frame:node_at(row) end
---@param node                          ux.treeview.NodeId
---@return integer|nil
function Frame:position(node) end
---@param row                           integer
---@param direction                     ux.treeview.Direction
---@return integer|nil
function Frame:navigate(row, direction) end
---Viewport reads are bounded to 512 rows, 1 MiB of row data, and 8192 matches/guides.
---@param first                         integer
---@param last                          integer
---@return ux.treeview.IRows
function Frame:rows(first, last) end
---@param node                          ux.treeview.NodeId
---@return ux.treeview.INode|nil
function Frame:node(node) end
---@return yoz.ux.treeview.Source
function Frame:source() end

---@class yoz.ux.treeview.ReadToken
---@class yoz.ux.treeview.QueryToken

---@class yoz.ux.treeview.Data
local Data = {}
---@param scope                         ?ux.treeview.IDataScope
---@param base                          ux.treeview.Revision
---@return yoz.ux.treeview.Upload
function Data:begin_import(scope, base) end
---@return yoz.ux.treeview.Source
function Data:source() end
---@param batch                         ux.treeview.IBatch
---@return yoz.ux.treeview.Ticket
function Data:batch(batch) end
---@param batch                         ux.treeview.IBatch
---@param authorization                 string
---@return yoz.ux.treeview.Ticket
function Data:task_batch(batch, authorization) end
---@param input                         ux.treeview.IImport
---@return yoz.ux.treeview.Ticket
function Data:import(input) end
---@param root                          ux.treeview.IRoot
---@param display                       ?ux.treeview.IDisplay
---@return yoz.ux.treeview.Ticket
function Data:create_state(root, display) end
---@param scope                         ux.treeview.IDataScope
---@return yoz.ux.treeview.Ticket
function Data:create_provider(scope) end
---@param nodes                         ux.treeview.NodeId[]
---@param retry                         ?boolean
---@return yoz.ux.treeview.Ticket
function Data:request_children(nodes, retry) end
---@return ux.treeview.IEffect[]
function Data:events() end
---@param token                         yoz.ux.treeview.ReadToken
---@param sequence                      ux.treeview.Revision
---@param records                       ux.treeview.Records
---@param done                          boolean
---@return yoz.ux.treeview.Ticket
function Data:children_page(token, sequence, records, done) end
---@param token                         yoz.ux.treeview.ReadToken
---@param sequence                      ux.treeview.Revision
---@param error                         ux.treeview.IError|string
---@return yoz.ux.treeview.Ticket
function Data:children_failed(token, sequence, error) end
---@param token                         yoz.ux.treeview.ReadToken
---@return yoz.ux.treeview.Ticket
function Data:children_cancelled(token) end
---@param token                         yoz.ux.treeview.QueryToken
---@param sequence                      ux.treeview.Revision
---@param records                       ux.treeview.Records
---@param done                          boolean
---@return yoz.ux.treeview.Ticket
function Data:query_page(token, sequence, records, done) end
---@param token                         yoz.ux.treeview.QueryToken
---@param sequence                      ux.treeview.Revision
---@param error                         ux.treeview.IError|string
---@return yoz.ux.treeview.Ticket
function Data:query_failed(token, sequence, error) end
---@param token                         yoz.ux.treeview.QueryToken
---@return yoz.ux.treeview.Ticket
function Data:query_cancelled(token) end
---@return integer
function Data:queue_depth() end
---@return boolean
function Data:is_disposed() end

---@class yoz.ux.treeview.State
local State = {}
---@return yoz.ux.treeview.Ticket
function State:refresh() end
---@param plan                          yoz.ux.treeview.RenderPlan
---@param minimum                       ?ux.treeview.Revision
---@return yoz.ux.treeview.RenderPlan|nil
function State:retarget_plan(plan, minimum) end
---@return string
function State:id() end
---@return yoz.ux.treeview.Frame
function State:snapshot() end
---@return {revisions: ux.treeview.IRevisions, locked: boolean, projection_error: ux.treeview.IError|nil}
function State:status() end
---@param frame                         yoz.ux.treeview.Frame
---@param minimum                       ?ux.treeview.Revision
---@return boolean
function State:applicable(frame, minimum) end
---@param command                       ux.treeview.ICommand
---@param context                       ?ux.treeview.IContext
---@return yoz.ux.treeview.Ticket
function State:dispatch(command, context) end
---@param revision                      ux.treeview.Revision
---@param deadline_ms                   ?integer
---@return yoz.ux.treeview.Ticket
function State:lock_selection(revision, deadline_ms) end
---@param token                         string
---@return yoz.ux.treeview.Ticket
function State:unlock_selection(token) end
---@param lock                          string
---@param cleanup                       string
---@param changes                       table[]
---@return yoz.ux.treeview.Ticket
function State:authorize_update(lock, cleanup, changes) end
---@return yoz.ux.treeview.View
function State:attach() end

---@class yoz.ux.treeview.Provider
local Provider = {}
---@param base                          ux.treeview.Revision
---@return yoz.ux.treeview.Upload
function Provider:begin_import(base) end
---@return string
function Provider:id() end
---@param revision                      ux.treeview.Revision
---@param records                       ux.treeview.Records
---@return yoz.ux.treeview.Ticket
function Provider:import(revision, records) end
---@param batch                         ux.treeview.IBatch
---@return yoz.ux.treeview.Ticket
function Provider:batch(batch) end
---@return yoz.ux.treeview.Ticket
function Provider:create_query() end

---@class yoz.ux.treeview.Query
local Query = {}
---@return string
function Query:id() end
---@return table
function Query:info() end
---@param input                         ux.treeview.IQueryInput
---@return yoz.ux.treeview.Ticket
function Query:start(input) end
---@return yoz.ux.treeview.Ticket
function Query:cancel() end

---@class yoz.ux.treeview.View
local View = {}
---@return string|nil
function View:id() end
---@return nil
function View:detach() end
---@return yoz.ux.treeview.Frame
function View:snapshot() end
---@param base                          ?yoz.ux.treeview.Frame
---@param target                        yoz.ux.treeview.Frame
---@param context                       ?ux.treeview.IRenderContext
---@param old_context                   ?ux.treeview.IRenderContext
---@param reset                         boolean
---@return yoz.ux.treeview.Ticket
function View:plan(base, target, context, old_context, reset) end

---@class yoz.ux.treeview.RenderPlan
local RenderPlan = {}
---@return yoz.ux.treeview.Frame
function RenderPlan:target() end
---@return {mode: string, base: string|nil, target: string, row_count: integer, reason: string, splices: integer[][], text_bytes: integer, written_rows: integer, compared_rows: integer, shared_rows: integer}
function RenderPlan:header() end
---RenderPlan text ranges use 0-based, end-exclusive coordinates.
---@param first                         integer
---@param last                          integer
---@param byte_limit                    integer
---@return string[]
---@return integer next_row
function RenderPlan:lines(first, last, byte_limit) end

---@class yoz.ux.treeview.Upload
local Upload = {}
---@param records                       ux.treeview.Records
---@return ux.treeview.IReply
function Upload:append(records) end
---@return yoz.ux.treeview.Ticket
function Upload:commit() end
---@return nil
function Upload:dispose() end

return M
