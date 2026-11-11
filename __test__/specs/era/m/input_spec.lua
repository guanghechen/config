local t = require("__test__.support.harness").new()
local prompt = require("__test__.support.explorer").prompt(t)
local open_ui, dialog, answer = prompt.open, prompt.dialog, prompt.answer

t:test("confirmation descriptions preserve trailing colons and spaces exactly", function()
  local context = open_ui({ "placeholder.txt" })
  context.ui:lua([[
    reply = false
    vim.ui.input({prompt = "  Overwrite?  \nTarget: target:\nSource: source:  ", inputtype = "confirmation"}, function(value)
      reply = value
    end)
  ]])
  local popup = dialog(context)
  t.assert_eq("Target: target:", popup.lines[1])
  t.assert_eq("Source: source:  ", popup.lines[2])
  answer(context, "<CR>")
  context.ui:wait_lua("return reply ~= false", 10000, "the confirmation must reply")
  t.assert_eq("", context.ui:lua("return reply"))
end)

t:test("invalid single-line defaults fail before allocating an input surface", function()
  local context = open_ui({ "placeholder.txt" })
  local result = context.ui:lua([[
    local wins, bufs = #vim.api.nvim_list_wins(), #vim.api.nvim_list_bufs()
    local ok = pcall(vim.ui.input, {prompt = "Input", default = "a\nb"}, function() end)
    return {ok = ok, windows = #vim.api.nvim_list_wins() - wins, buffers = #vim.api.nvim_list_bufs() - bufs}
  ]])
  t.assert_false(result.ok)
  t.assert_eq(0, result.windows)
  t.assert_eq(0, result.buffers)
end)

t:run()
