local Observable = require("eve.lib.collection.observable")
local count = Observable.from_value(1)

vim.keymap.set({ "n", "v" }, "<leader>qq", "<cmd>qa<cr>")
require("eve.lib.debug").log({ count1 = count })

vim.b.count = count
require("eve.lib.debug").log({ count2 = vim.b.count })
require("eve.lib.debug").log({ count3 = count })
