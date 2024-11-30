local __module_name__ = "ghc.command.copy" ---@type string

local Observable = require("eve.collection.observable")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@alias ghc.command.copy.current_filepath_candidate
---| "absolute"
---| "relative"

---@type ghc.command.copy.current_filepath_candidate[]
local copy_current_filepath_candidates = {
  "absolute",
  "relative",
}

---@param candidate                     ghc.command.copy.current_filepath_candidate
---@return nil
local function copy_current_filepath(candidate)
  if candidate == "absolute" then
    local filepath = eve.path.current_filepath() ---@type string
    local content = filepath ---@type string

    vim.fn.setreg("+", content)
    eve.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (absolute) to system clipboard!",
    })
  elseif candidate == "relative" then
    local cwd = eve.path.cwd() ---@type string
    local filepath = eve.path.current_filepath() ---@type string
    local content = eve.path.relative(cwd, filepath, true) ---@type string

    vim.fn.setreg("+", content)
    eve.reporter.info({
      from = __module_name__,
      message = "Copied current buffer filepath (relative) to system clipboard!",
    })
  else
    eve.reporter.error({
      from = __module_name__,
      message = "Failed to copy current filepath, unknown candidate!",
      details = { candidate = candidate },
    })
  end
end

eve.commander
  .register({
    uuid = uuids.copy_char_under_cursor,
    desc = "copy: char under cursor",
    action = function()
      local col = vim.fn.col(".")
      local char = vim.fn.getline("."):sub(col, col)
      vim.fn.setreg("+", char)
    end,
  })
  .register({
    uuid = uuids.copy_current_filepath,
    desc = "copy: current filepath",
    nargs = "?",
    candidates = vim.list_slice(copy_current_filepath_candidates),
    action = function(args)
      local arg = type(args) == "string" and args:lower() or "" ---@type string
      if vim.tbl_contains(copy_current_filepath_candidates, arg) then
        copy_current_filepath(arg)
      else
        fml.fn.select({
          title = "Copy current filepath",
          flag_fuzzy = true,
          flag_regex = false,
          input = Observable.from_value(arg),
          dimension = {
            row = 5,
            width = 50,
          },
          get_present = function()
            return "relative"
          end,
          fetch_items = function()
            local items = {} ---@type fml.t.ux.select.IItem[]
            for _, candidate in ipairs(copy_current_filepath_candidates) do
              table.insert(items, { uuid = candidate, text = candidate })
            end
            return items
          end,
          on_confirm = function(item)
            local candidate = item.uuid ---@type string
            copy_current_filepath(candidate)
          end,
        })
      end
    end,
  })
