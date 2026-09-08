---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.python" ---@type string

local Future = require("stl.c.future")
local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt
local fn_select_python_venv = dot.G.register_anonymous_fn(function()
  dot.command.definitions.lsp.select_python_venv:execute()
end)

---@class era.m.nvimbar.component.python
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.env(position)
  local hln_text = position .. "_python_env_text"
  local versions = {} ---@type table<string, string>

  ---@param version                     ?string
  ---@param venv                        ?string
  ---@param path                        ?string
  ---@return { text: string, hltext: string, path: string|nil }
  local function snapshot(version, venv, path)
    local text = (version and version .. " " or "") .. "(" .. (venv or "unknown") .. ")  "
    return { text = text, hltext = btn(txt(text, hln_text), fn_select_python_venv), path = path }
  end

  return {
    name = "python:env",

    tight = true,
    will_change = function(context, prev_context, snapshot)
      return context.filetype ~= prev_context.filetype
        or (dot.context.lsp.python_venv_path:snapshot() or "") ~= (snapshot and snapshot.path or "")
    end,
    refresh = function(context, token)
      local path = dot.context.lsp.python_venv_path:snapshot()
      local venv = path and path ~= "" and yoz.path.basename(path) or nil
      if context.filetype ~= "python" and venv == nil then
        return nil
      end
      local python = dot.context.lsp.get_python_bin_path()
      if python == nil then
        return snapshot(nil, venv, path)
      end
      if versions[python] then
        return snapshot(versions[python], venv, path)
      end

      return Future.new(function(resolve, reject)
        local finished = false
        local subscription
        local process
        ---@return nil
        local function finish(ok, result)
          if finished then
            return
          end
          finished = true
          if subscription then
            subscription:unsubscribe()
          end
          if ok then
            resolve(result)
          else
            reject(result)
          end
        end
        process = vim.system(
          { python, "--version" },
          { text = true },
          vim.schedule_wrap(function(result)
            if finished or token:is_cancelled() then
              return
            end
            if result.code ~= 0 then
              finish(false, result.stderr or "Failed to read Python version")
              return
            end
            local version = (result.stdout or ""):match("(%d+%.%d+%.%d+)")
            if version == nil then
              finish(false, "Failed to parse Python version")
              return
            end
            versions[python] = version
            finish(true, snapshot(version, venv, path))
          end)
        )
        subscription = token:on_cancel(function()
          if not finished then
            process:kill(15)
            finish(false, "Python version request cancelled")
          end
        end)
      end)
    end,
  }
end

return M
