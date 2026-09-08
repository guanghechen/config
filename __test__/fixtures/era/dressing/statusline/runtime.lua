---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.dressing.statusline.runtime" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local M = {}

--- Assemble the real bar with only the constructors exercised by the native scenario.
---@param t                             __test__.support.Harness
---@param constructors                  table<string, table<string, fun(position: stl.t.NvimbarPositionEnum): era.m.nvimbar.IRawComponent>>
---@return stl.reporter.IOptions[]
function M.setup(t, constructors)
  local errors = {} ---@type stl.reporter.IOptions[]
  local stl = require("stl")
  t:patch_global("stl", stl)
  t:patch_table(stl, "reporter", {
    error = function(report)
      errors[#errors + 1] = report
    end,
  })
  bootstrap.with_runtime(t, {
    dot = {
      path = {
        cwd = function()
          return "/project"
        end,
      },
      theme = {
        hlgroup = {
          common = {
            resolve_mode = function()
              local mode = vim.api.nvim_get_mode().mode
              return mode, mode == "c" and "COMMAND" or "NORMAL"
            end,
          },
        },
      },
      state = { status = { dirtier_statusline = stl.c.Dirtier.new({ dirty = true }) } },
    },
    yoz = { path = {
      basename = function(path)
        return path:match("[^/]*$")
      end,
    } },
  })

  local components = setmetatable({
    lazy = require("era.m.nvimbar").component.lazy,
  }, {
    __index = function(_, group)
      return setmetatable({}, {
        __index = function(_, name)
          local constructor = constructors[group] and constructors[group][name]
          if constructor then
            return constructor
          end
          return function()
            return { name = group .. ":" .. name, refresh = function() end }
          end
        end,
      })
    end,
  })
  bootstrap.with_era(t, {
    m = { nvimbar = { Nvimbar = require("era.m.nvimbar.nvimbar"), component = components } },
  })
  return errors
end

return M
