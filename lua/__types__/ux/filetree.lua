---@meta

---@class yoz.ux.filetree
local M = {}
---@param path                          string
---@return yoz.ux.treeview.Ticket
function M.open(path) end

---@class yoz.ux.filetree.Data
local Data = {}
---@param previous                      ?string
---@return ux.filetree.IWatchStatus|nil
function Data:watch_status(previous) end
---@param hints                         {frame: yoz.ux.treeview.Frame, first: integer, last: integer}[]
---@return nil
function Data:watch_visible(hints) end
---@return boolean
function Data:is_busy() end
---@return {retained_bytes: integer, nodes: integer, queue_depth: integer}
function Data:stats() end
---@return yoz.ux.treeview.Data
function Data:treeview() end
---@return string
function Data:root() end
---@return yoz.ux.treeview.Source
function Data:source() end
---@param root                          ?ux.treeview.IRoot
---@param display                       ?ux.treeview.IDisplay
---@return yoz.ux.treeview.Ticket
function Data:create_state(root, display) end
---@param path                          string
---@return yoz.ux.treeview.Ticket
function Data:resolve(path) end
---@param source                        yoz.ux.treeview.Source
---@param node                          string
---@return yoz.ux.filetree.Resource
function Data:inspect(source, node) end
---@param resource                      yoz.ux.filetree.Resource
---@return yoz.ux.treeview.Ticket
function Data:details(resource) end

---@class ux.filetree.IResourceDetails
---@field size                          integer
---@field permissions                   string
---@field mode                          string
---@field modified                      ?string
---@field accessed                      ?string
---@field created                       ?string
---@param state                         yoz.ux.treeview.State
---@return yoz.ux.treeview.Ticket
function Data:refresh(state) end

---@param root                          string
---@param revision                      string|integer
---@param snapshot                      ?yoz.git.StatusSnapshot
---@param ignored                       ?yoz.git.IgnoreCache
---@return yoz.ux.treeview.Ticket
function Data:set_git(root, revision, snapshot, ignored) end
---@param namespace                     integer
---@param bufnr                         integer
---@param revision                      string|integer
---@param path                          ?string
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

---@class ux.filetree.IAnnotation
---@field diagnostics                   integer[] Error, Warn, Info, Hint counts; directories include descendants.
---@field git                           integer Bitset using yoz.git.codes.
---@field staged                        boolean
---@field unstaged                      boolean
---@class ux.filetree.IAnnotationRows
---@field revision                      string
---@field frame                         string
---@field first                         integer
---@field rows                          ux.filetree.IAnnotation[]

---@class yoz.ux.filetree.Resource
local Resource = {}
---@return string
function Resource:node() end
---@return yoz.ux.treeview.Source
function Resource:source() end
---@return string
function Resource:path() end
---@return ux.filetree.IResourceInfo
function Resource:info() end

---@class ux.filetree.IResourceInfo
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
---@field link                          ?string

---@class ux.filetree.IOptions
---@field on_effect                     ?fun(effect: ux.filetree.IEffect): nil

---@alias ux.filetree.IEffect ux.treeview.IEffect|{kind: "WatchStatus", status: ux.filetree.IWatchStatus}
---@class ux.filetree.IWatchStatus
---@field revision                      string
---@field directories                   integer
---@field covered                       yoz.ux.treeview.NodeIds
---@field limited                       boolean
---@field error                         ?ux.treeview.IError

---@class ux.filetree.IOperationPlan
---@field kind                          "copy"|"move"|"delete"|"trash"
---@field source                        yoz.ux.treeview.Source
---@field nodes                         yoz.ux.treeview.NodeIds|string[]
---@field target                        ?yoz.ux.filetree.Resource
---@field name                          ?string
---@field task                          ?{state: ux.treeview.State, lock: string, cleanup: string}
---@field prepare_move                  ?boolean Request editor preparation after conflict confirmation and before move IO.

---@param plan                          ux.filetree.IOperationPlan
---@return yoz.ux.filetree.Job
function Data:start_operation(plan) end
---@param source                        yoz.ux.filetree.Resource
---@param target                        yoz.ux.filetree.Resource
---@return yoz.ux.treeview.Ticket
function Data:check_transfer_target(source, target) end

---@class ux.filetree.ICreatePlan
---@field target                        yoz.ux.filetree.Resource
---@field path                          string
---@field directory                     boolean

---@param plan                          ux.filetree.ICreatePlan
---@return yoz.ux.filetree.Job
function Data:start_create(plan) end

---@class yoz.ux.filetree.Job
local Job = {}
---@return ux.filetree.IJobStatus
function Job:status() end
---@param first                         integer
---@param last                          integer
---@return ux.filetree.IItemResult[]
function Job:results(first, last) end
---@param token                         string
---@param overwrite                     boolean
---@return nil
function Job:confirm(token, overwrite) end
---@return nil
function Job:cancel() end

---@class ux.filetree.IJobStatus
---@field terminal                      boolean
---@field cancelling                    boolean
---@field cancelled                     boolean
---@field results                       integer
---@field bytes                         integer
---@field confirmation                  ?{kind: "overwrite"|"prepare_move", token: string, node: string, source: string|nil, target: string|nil, source_label: string, target_label: string}
---@field error                         ?ux.treeview.IError
---@field cleanup                       ?("success"|ux.treeview.IError)

---@class ux.filetree.IItemResult
---@field node                          string
---@field source                        ?string
---@field source_label                  string
---@field target                        ?string
---@field target_label                  ?string
---@field source_physical               ?string
---@field target_physical               ?string
---@field status                        "success"|"failed"|"skipped"
---@field error                         ?ux.treeview.IError
---@field error_kind                    ?string
---@field os_code                       ?integer
---@field sync_error                    ?ux.treeview.IError
