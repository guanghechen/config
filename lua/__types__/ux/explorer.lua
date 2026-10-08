---@meta

---@class yoz.ux.explorer
local M = {}

---@param data                          yoz.ux.filetree.Data
---@param state                         yoz.ux.treeview.State
---@param workspace                     ux.filetree.Path|yoz.ux.filetree.Resource
---@return yoz.ux.explorer.State
function M.new(data, state, workspace) end

---@class yoz.ux.explorer.State
local State = {}

---@return string|nil
function State:workspace() end
---@return ux.filetree.Path
function State:workspace_path() end
---@return string|nil
function State:previous() end
---@param frame                         yoz.ux.treeview.Frame
---@return "select"|"copy"|"cut"|nil
function State:mode(frame) end
---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@param mark                          "toggle"|"select"|"copy"|"cut"
---@param visual                        boolean
---@return yoz.ux.treeview.Ticket
function State:mark(frame, first, last, mark, visual) end
---Resolve fold intent in owner order, preserving the key-time target and view context.
---@param frame                         yoz.ux.treeview.Frame
---@param node                          string
---@param kind                          "toggle"|"recursive"|"collapse"
---@return yoz.ux.treeview.Ticket
function State:fold(frame, node, kind) end
---Cancel copy/cut while retaining selection; otherwise clear the selection.
---@return yoz.ux.treeview.Ticket
function State:cancel_transfer_or_clear_selection() end
---Read the captured range as outermost subtrees without changing selection or its purpose.
---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@return yoz.ux.treeview.Ticket
function State:inspect_range(frame, first, last) end
---Lock an empty selection after validating the captured cursor resource and selection intent.
---@param frame                         yoz.ux.treeview.Frame
---@param node                          string
---@return yoz.ux.treeview.Ticket
function State:prepare_cursor(frame, node) end
---Inspect a complete selection with its Source, or atomically lock an incomplete selection for preparation.
---@return yoz.ux.treeview.Ticket
function State:prepare_selection() end
---@param node                          string
---@param reveal                        boolean
---@return yoz.ux.treeview.Ticket
function State:navigate(node, reveal) end
---Resolve the current root's parent at this request's position in the owner queue.
---@return yoz.ux.treeview.Ticket
function State:navigate_parent() end
---@param path                          ux.filetree.Path
---@return yoz.ux.treeview.Ticket
function State:reveal_path(path) end
---@param plan                          ux.filetree.IOperationPlan
---@return yoz.ux.filetree.Job
function State:start_operation(plan) end
---@param plan                          ux.filetree.ICreatePlan
---@return yoz.ux.filetree.Job
function State:start_create(plan) end
