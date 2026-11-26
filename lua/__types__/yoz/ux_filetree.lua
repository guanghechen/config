---@meta

---Slash-separated path; Unix backslashes and filename bytes are literal. Windows prefixes are retained.
---Native separators are used only inside filesystem/OS boundaries, including for physical paths.
---@alias yoz.ux.filetree.Path string

---@class yoz.ux.filetree
local M = {}
---@param path                          yoz.ux.filetree.Path
---@return yoz.ux.treeview.Ticket
function M.open(path) end

---@class yoz.ux.filetree.Data
local Data = {}
---@param previous                      ?string
---@return yoz.ux.filetree.IWatchStatus|nil
function Data:watch_status(previous) end
---Advances once per watch delivery that carries filesystem events, never for reads.
---@return integer
function Data:watch_activity() end
---@param hints                         {frame: yoz.ux.treeview.Frame, first: integer, last: integer}[]
---@return nil
function Data:watch_visible(hints) end
---@return boolean
function Data:is_busy() end
---Observe accepted browse/refresh work; a settled scan may have failed and its frame may still be preparing.
---@return boolean
function Data:is_settled() end
---@return {retained_bytes: integer, nodes: integer, queue_depth: integer}
function Data:stats() end
---@return yoz.ux.treeview.Data
function Data:treeview() end
---@return string
function Data:root() end
---@return yoz.ux.treeview.Source
function Data:source() end
---@param root                          ?yoz.ux.treeview.IRoot
---@param display                       ?yoz.ux.treeview.IDisplay
---@return yoz.ux.treeview.Ticket
function Data:create_state(root, display) end
---@param path                          yoz.ux.filetree.Path
---@return yoz.ux.treeview.Ticket
function Data:resolve(path) end
---@param source                        yoz.ux.treeview.Source
---@param node                          string
---@return yoz.ux.filetree.Resource
function Data:inspect(source, node) end
---@param resource                      yoz.ux.filetree.Resource
---@return yoz.ux.treeview.Ticket
function Data:details(resource) end
---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@param parent_context                ?boolean Use captured parent metadata for the context row.
---@return yoz.ux.treeview.Ticket
function Data:listing(frame, first, last, parent_context) end
---@param state                         yoz.ux.treeview.State
---@return yoz.ux.treeview.Ticket
function Data:refresh(state) end

---@param root                          yoz.ux.filetree.Path
---@param revision                      string|integer
---@param snapshot                      ?yoz.git.StatusSnapshot
---@param ignored                       ?yoz.git.IgnoreCache
---@return yoz.ux.treeview.Ticket
function Data:set_git(root, revision, snapshot, ignored) end
---@param namespace                     integer
---@param bufnr                         integer
---@param revision                      string|integer
---@param path                          ?yoz.ux.filetree.Path
---@param counts                        integer[]
---@return yoz.ux.treeview.Ticket
function Data:set_diagnostics(namespace, bufnr, revision, path, counts) end
---@return string
function Data:annotation_revision() end
---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@return yoz.ux.treeview.Ticket
function Data:annotations(frame, first, last) end
---@param frame                         yoz.ux.treeview.Frame
---@param row                           integer
---@param kind                          "git"|"diagnostic"|"error"|"warning"
---@param forward                       boolean
---@return yoz.ux.treeview.Ticket
function Data:next_annotation(frame, row, kind, forward) end

---@class yoz.ux.filetree.Resource
local Resource = {}
---@return string
function Resource:node() end
---@return yoz.ux.treeview.Source
function Resource:source() end
---@return yoz.ux.filetree.Path
function Resource:path() end
---@return yoz.ux.filetree.IResourceInfo
function Resource:info() end

---@class yoz.ux.filetree.IResourceInfo
---@field node                          string
---@field label                         string
---@field kind                          "file"|"directory"|"link"|"other"
---@field identity                      string
---@field size                          integer
---@field mode                          integer
---@field uid                           integer
---@field gid                           integer
---@field modified_ns                   ?string
---@field created_ns                    ?string
---@field directory                     boolean
---@field cycle                         boolean
---@field target_unknown                boolean
---@field target_kind                   ?("file"|"directory"|"link"|"other")
---@field link                          ?yoz.ux.filetree.Path

---@class yoz.ux.filetree.IWatchStatus
---@field revision                      string
---@field roots                         integer Actual OS subscription roots; recursive on macOS.
---@field directories                   integer Covered physical directory interests, excluding subscription-only roots.
---@field covered                       yoz.ux.treeview.NodeIds Logical occurrences reached by the covered interests.
---@field limited                       boolean
---@field error                         ?yoz.ux.treeview.IError

---@class yoz.ux.filetree.IListingRow
---@field node                          yoz.ux.treeview.NodeId
---@field directory                     boolean
---@field permissions                   string
---@field size                          string
---@field date                          string
---@field owner                         string
---@field group                         string

---@class yoz.ux.filetree.IResourceDetails
---@field size                          integer
---@field permissions                   string
---@field mode                          string
---@field modified                      ?string
---@field accessed                      ?string
---@field created                       ?string

---@class yoz.ux.filetree.IAnnotation
---@field diagnostics                   integer[] Error, Warn, Info, Hint counts; directories include descendants.
---@field git                           integer Bitset using yoz.git.codes.
---@field staged                        boolean
---@field unstaged                      boolean

---@class yoz.ux.filetree.IAnnotationRows
---@field revision                      string
---@field frame                         string
---@field first                         integer
---@field rows                          yoz.ux.filetree.IAnnotation[]

---@class yoz.ux.filetree.IOperationPlan
---@field kind                          "copy"|"move"|"delete"|"trash"
---@field source                        yoz.ux.treeview.Source
---@field nodes                         yoz.ux.treeview.NodeIds|string[]
---@field target                        ?yoz.ux.filetree.Resource
---@field name                          ?string
---@field task                          ?{state: yoz.ux.treeview.State, lock: string, cleanup: string}
---@field prepare_move                  ?boolean Request editor preparation after conflict confirmation and before move IO.

---@param plan                          yoz.ux.filetree.IOperationPlan
---@return yoz.ux.filetree.Job
function Data:start_operation(plan) end
---@param source                        yoz.ux.filetree.Resource
---@param target                        yoz.ux.filetree.Resource
---@return yoz.ux.treeview.Ticket
function Data:check_transfer_target(source, target) end

---@class yoz.ux.filetree.ICreatePlan
---@field target                        yoz.ux.filetree.Resource
---@field path                          yoz.ux.filetree.Path
---@field directory                     boolean

---@param plan                          yoz.ux.filetree.ICreatePlan
---@return yoz.ux.filetree.Job
function Data:start_create(plan) end

---@class yoz.ux.filetree.Job
local Job = {}
---@param revision                      string
---@return yoz.ux.filetree.IJobStatus|nil
---@overload fun(self: yoz.ux.filetree.Job): yoz.ux.filetree.IJobStatus
function Job:status(revision) end
---@param first                         integer
---@param last                          integer
---@return yoz.ux.filetree.IItemResult[]
function Job:results(first, last) end
---@param token                         string
---@param overwrite                     boolean
---@return nil
function Job:confirm(token, overwrite) end
---@return nil
function Job:cancel() end

---@class yoz.ux.filetree.IJobStatus
---@field revision                      string
---@field terminal                      boolean
---@field cancelling                    boolean
---@field cancelled                     boolean
---@field results                       integer
---@field processed                     integer Completed processing decisions, independent of published/compacted results.
---@field bytes                         integer
---@field phase                         "preparing"|"reading"|"working"|"publishing"|"cleanup"|"complete"
---@field confirmation                  ?{kind: "overwrite"|"prepare_move", token: string, item: string, node: string|nil, source: yoz.ux.filetree.Path|nil, target: yoz.ux.filetree.Path|nil, source_label: string, target_label: string}
---@field error                         ?yoz.ux.treeview.IError
---@field cleanup                       ?("success"|yoz.ux.treeview.IError)

---@class yoz.ux.filetree.IItemResult
---@field item                          string
---@field node                          ?string
---@field source                        ?yoz.ux.filetree.Path
---@field source_label                  string
---@field target                        ?yoz.ux.filetree.Path
---@field target_label                  ?string
---@field source_physical               ?yoz.ux.filetree.Path
---@field target_physical               ?yoz.ux.filetree.Path
---@field status                        "success"|"failed"|"skipped"
---@field error                         ?yoz.ux.treeview.IError
---@field error_kind                    ?string
---@field os_code                       ?integer
---@field sync_error                    ?yoz.ux.treeview.IError
