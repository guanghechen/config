local t = require("__test__.support.harness").new()

---@param ui                            __test__.support.UI
---@param expression                    string
---@return nil
local function wait_for(ui, expression)
  ui:wait_until(function()
    return ui:lua("return " .. expression)
  end, 5000)
end

---@param consumer                      "show_send_target"|"show_submit_to"
---@return __test__.support.UI
local function session(consumer)
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:start({ width = 100, height = 32, runtime = "ark" })
  ui:lua(
    [[
    local consumer = ...
    errors, received, confirmations = {}, nil, 0
    stl.reporter.error = function(value) errors[#errors + 1] = value.message end
    sources = {
      { id = "source-a", agent = "fixture", cwd = "/tmp" },
      { id = "source-b", agent = "fixture", cwd = "/tmp" },
    }
    package.loaded["era.m.ai"] = {
      config = { agent_labels = { fixture = "Fixture" } },
      action = {
        get_source_identifier = function(source) return source.id end,
        collect_items = function()
          return {
            { type = "running", agent = "fixture", source = sources[1] },
            { type = "running", agent = "fixture", source = sources[2] },
          }
        end,
      },
      state = { is_attached = function() return false end },
      tmux = { get_current_info = function() return {} end },
    }
    package.loaded["era.m.ai.picker"] = nil
    local List = require("era.m.picker.composer.list")
    local new = List.new
    List.new = function(props)
      inputs = props
      picker = new(props)
      return picker
    end
    local capture = function(items)
      received = {}
      confirmations = confirmations + 1
      for _, item in ipairs(items) do
        assert(item == sources[1] or item == sources[2], "source payload identity changed")
        received[#received + 1] = item.id
      end
    end
    local Picker = require("era.m.ai.picker")
    if consumer == "show_send_target" then
      Picker.show_send_target(sources, capture)
    else
      Picker.show_submit_to(capture)
    end
    focus_item = function(uuid)
      vim.cmd.stopinsert()
      vim.api.nvim_set_current_win(picker.result:get_winnr())
      picker.result:set_lnum_current(assert(picker._treeview:retrieve_lnum("item:" .. uuid)))
    end
    toggle = function() inputs.keymaps_result[1].callback() end
    confirm = function()
      inputs.on_confirm(picker, picker:retrieve(picker.result.lnum_current:snapshot()))
    end
    marked = function(uuid)
      local frame = picker._treeview:frame()
      return frame and frame:flags(frame:source():id("item:" .. uuid)).marked
    end
  ]],
    consumer
  )
  wait_for(ui, "picker._treeview.view and picker._treeview:retrieve_lnum('item:source-a') ~= nil")
  return ui
end

for _, consumer in ipairs({ "show_send_target", "show_submit_to" }) do
  t:test(consumer .. " publishes native marks and confirms selected items outside the filter", function()
    local ui = session(consumer)
    ui:lua("focus_item('source-a'); toggle()")
    wait_for(ui, "marked('source-a') and not picker._treeview:selection_pending()")
    ui:lua("picker.finder:set_content('source-b')")
    wait_for(ui, "picker._treeview:linecount() == 1 and picker:retrieve(1).uuid == 'source-b'")
    ui:lua("focus_item('source-b'); confirm()")
    wait_for(ui, "received ~= nil")
    t.assert_eq("source-a", ui:lua("return table.concat(received, ',')"))
    t.assert_eq(0, ui:lua("return #errors"))
  end)

  t:test(consumer .. " waits for a Tab immediately followed by confirmation", function()
    local ui = session(consumer)
    ui:lua("focus_item('source-a'); toggle(); focus_item('source-b'); confirm()")
    wait_for(ui, "received ~= nil")
    t.assert_eq("source-a", ui:lua("return table.concat(received, ',')"))
    t.assert_eq(1, ui:lua("return confirmations"))
    t.assert_eq(0, ui:lua("return #errors"))
  end)

  t:test(consumer .. " uses the captured current item after deselection", function()
    local ui = session(consumer)
    ui:lua("focus_item('source-a'); toggle()")
    wait_for(ui, "marked('source-a') and not picker._treeview:selection_pending()")
    ui:lua("toggle(); focus_item('source-b'); confirm()")
    wait_for(ui, "received ~= nil")
    t.assert_eq("source-b", ui:lua("return table.concat(received, ',')"))
    t.assert_eq(0, ui:lua("return #errors"))
  end)

  t:test(consumer .. " accepts confirmation once while selection is pending", function()
    local ui = session(consumer)
    ui:lua("focus_item('source-a'); toggle(); confirm(); confirm()")
    wait_for(ui, "picker:isdisposed()")
    t.assert_eq(1, ui:lua("return confirmations"))
    t.assert_eq("source-a", ui:lua("return table.concat(received, ',')"))
    t.assert_eq(0, ui:lua("return #errors"))
  end)

  t:test(consumer .. " drops a pending confirmation when closed", function()
    local ui = session(consumer)
    ui:lua("focus_item('source-a'); toggle(); confirm(); picker:close()")
    wait_for(ui, "picker:isdisposed()")
    ui:lua("vim.wait(50, function() return false end, 5)")
    t.assert_eq(0, ui:lua("return confirmations"))
    t.assert_eq(0, ui:lua("return #errors"))
  end)
end

t:test("send to all stays an action row and empty selection confirms every source", function()
  local ui = session("show_send_target")
  ui:lua("focus_item('__send_to_all__'); toggle()")
  t.assert_false(ui:lua("return marked('__send_to_all__')"))
  ui:lua("confirm()")
  wait_for(ui, "received ~= nil")
  t.assert_eq("source-a,source-b", ui:lua("return table.concat(received, ',')"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:run()
