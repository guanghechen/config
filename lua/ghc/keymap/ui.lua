local fn = {
  dismiss_notifications = function()
    require("notify").dismiss({
      silent = true,
      pending = true
    })
  end
}

-- highlights under cursor
vim.keymap.set("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })

-- notify
vim.keymap.set("n", "<leader>un", fn.dismiss_notifications, { noremap = true, desc = "Dismiss All Notifications" })

