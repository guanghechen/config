---@meta

---@class yoz.ux.explorer
local M = {}

---@param data                          yoz.ux.filetree.Data
---@param state                         yoz.ux.treeview.State
---@return yoz.ux.explorer.State
function M.new(data, state) end

---@class yoz.ux.explorer.State
local State = {}

---@return string
function State:workspace() end
---@return string
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
---Read the captured range as outermost subtrees without changing selection or its purpose.
---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@return yoz.ux.treeview.Ticket
function State:inspect_range(frame, first, last) end
---@param node                          string
---@param reveal                        boolean
---@return yoz.ux.treeview.Ticket
function State:navigate(node, reveal) end
---@param path                          string
---@return yoz.ux.treeview.Ticket
function State:reveal_path(path) end
---@param plan                          ux.filetree.IOperationPlan
---@return yoz.ux.filetree.Job
function State:start_operation(plan) end
---@param plan                          ux.filetree.ICreatePlan
---@return yoz.ux.filetree.Job
function State:start_create(plan) end
---@return yoz.ux.filetree.Job|nil
function State:job() end
