local textarea = fml.ui.Textarea.new({
  position = "center",
  width = 0.4,
  height = 0.4,
  title = "Shit!",
  validate = fml.util.noop,
  on_close = function()
    fml.debug.log("on close")
  end,
  on_confirm = function(text)
    fml.debug.log("on confirm:", { text = text or "nil" })
  end,
})
textarea:open({ initial_text = "haha" })
