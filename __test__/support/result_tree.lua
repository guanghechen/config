---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.result_tree" ---@type string

local M = {}

---@param future                        stl.c.Future
---@return table
function M.await(future)
  assert(
    vim.wait(10000, function()
      return future:is_done()
    end, 1),
    "native result publication timed out"
  )
  assert(not future:is_failed(), future:get_error())
  local reply = future:get_result()
  assert(reply.kind ~= "Rejected", vim.inspect(reply))
  return reply
end

---@param tree                          era.view.ResultTree
---@param options                       ?table
---@return yoz.ux.treeview.Frame
function M.publish(tree, options)
  M.await(tree:publish(vim.tbl_extend("force", { mode = "tree", rootuuid = tree.source.root }, options or {})))
  return assert(tree:frame())
end

return M
