local fn = {
  dismiss_notifications = function()
    require("notify").dismiss({
      silent = true,
      pending = true
    })
  end
}

-- notify
vim.keymap.set("n", "<leader>un", fn.dismiss_notifications, { noremap = true, desc = "Dismiss All Notifications" })
