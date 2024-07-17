local oxi = require("fml.std.oxi")
local Observable = require("fml.collection.observable")

---@type fml.types.ui.select.IItem[]
local items = {
  { display = "lua/fml/collection/batch_disposable.lua" },
  { display = "lua/fml/collection/batch_handler.lua" },
  { display = "lua/fml/collection/circular_queue.lua" },
  { display = "lua/fml/collection/disposable.lua" },
  { display = "lua/fml/collection/history.lua" },
  { display = "lua/fml/collection/observable.lua" },
  { display = "lua/fml/collection/subscriber.lua" },
  { display = "lua/fml/collection/subscribers.lua" },
  { display = "lua/fml/collection/ticker.lua" },
  { display = "lua/fml/constant.lua" },
}
local select = fml.ui.select.Select.new({
  state = fml.ui.select.State.new({
    title = "Select file",
    uuid = oxi.uuid(),
    items = items,
    input = Observable.from_value(""),
    visible = Observable.from_value(false),
  }),
  on_confirm = function(item, idx)
    fml.debug.log("confirm:", { item = item, idx = idx })
  end,
})

select:toggle()
