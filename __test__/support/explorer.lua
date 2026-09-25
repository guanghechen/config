---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.explorer" ---@type string

local M = {}

---@param name                          string
---@return table
function M.new(name)
  local fixture = require("__test__.support.filetree").new(name)
  local t = fixture.t
  t:patch_global("stl", require("stl"))
  t:patch_global("dot", require("dot"))
  t:patch_global("era", require("era"))
  local messages = {}
  t:patch_table(stl.reporter, "warn", function(value)
    messages[#messages + 1] = value.message
  end)
  t:patch_table(stl.reporter, "error", function(value)
    error(value.message)
  end)
  t:patch_table(stl.reporter, "info", function() end)
  t:patch_table(dot.path, "is_git_repo", function()
    return false
  end)
  local Widget = require("era.m.explorer.widget")
  local Observable = require("stl.c.observable")

  ---@param path                        string
  ---@param options                     ?table
  ---@return era.m.explorer.Widget
  function fixture.widget(path, options)
    t:patch_table(dot.path, "workspace", function()
      return path
    end)
    local props = vim.tbl_extend("force", {
      name = "test-" .. vim.uv.hrtime(),
      root = path,
      o_width = Observable.from_value(30),
      o_flag_selected = Observable.from_value(false),
      o_flag_viewtype = Observable.from_value("tree"),
      o_flag_foldempty = Observable.from_value(true),
      o_flag_hidden = Observable.from_value(true),
    }, options or {})
    local widget = Widget.new(props)
    t:defer(function()
      widget:dispose()
    end)
    widget:focus()
    t.wait_until(function()
      local view = widget._views[vim.api.nvim_get_current_tabpage()]
      return view and view:frame() and not widget._session.data._native:is_busy()
    end, 10000)
    return widget
  end

  ---@param widget                      era.m.explorer.Widget
  ---@param path                        string
  ---@return yoz.ux.filetree.Resource
  function fixture.cursor(widget, path)
    local session, view = widget:context()
    local resource = fixture.await(session.data:resolve(path))
    t.wait_until(function()
      return view:frame() and view:frame():position(resource:node()) ~= nil
    end, 10000)
    vim.api.nvim_win_set_cursor(view.winnr, { view:frame():position(resource:node()), 0 })
    fixture.await(session.state:dispatch({ kind = "set_cursor", node = resource:node() }, { frame = view:frame() }))
    return resource
  end

  ---@param widget                      era.m.explorer.Widget
  ---@return nil
  function fixture.idle(widget)
    t.wait_until(function()
      local session = widget._session
      return not session.preparing
        and session.job == nil
        and not session.state:status().locked
        and not session.data._native:is_busy()
    end, 10000)
  end
  fixture.messages = messages
  return fixture
end

return M
