---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.dressing.scenario" ---@type string

-- The terminal side of `__test__.support.process.scenario`: screen reads and the result it waits for.

local M = {}

---The text of screen row `row` from the first column through `last_col`.
---@param row                           integer
---@param last_col                      integer
---@return string
function M.screenline(row, last_col)
  local chars = {} ---@type string[]
  for col = 1, last_col do
    chars[#chars + 1] = vim.fn.screenstring(row, col)
  end
  return table.concat(chars)
end

---Writes `result` as JSON to the file `$NVIM_TEST_RESULT` names and quits.
---@param result                        table
---@return nil
function M.finish(result)
  vim.fn.writefile({ vim.json.encode(result) }, assert(vim.env.NVIM_TEST_RESULT))
  vim.cmd("qa!")
end

return M
