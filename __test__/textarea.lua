---@diagnostic disable: lowercase-global

---@return nil
function test_textarea()
  local textarea = fml.ui.Textarea.new({
    position = "center",
    width = 0.4,
    height = 0.4,
    title = "Shit!",
    on_close = function()
      eve.debug.log("on close")
    end,
    on_confirm = function(text)
      eve.debug.log("on confirm:", { text = text or "nil" })
      return true
    end,
  })
  textarea:open({ initial_lines = { "haha" } })
end

---@return nil
function test_input()
  local input = fml.ui.Input.new({
    position = "center",
    width = 0.4,
    title = "Shit!",
    on_close = function()
      eve.debug.log("on close")
    end,
    on_confirm = function(text)
      eve.debug.log("on confirm:", { text = text or "nil" })
      return true
    end,
  })
  input:open({ initial_value = "haha" })
end

test_input()
