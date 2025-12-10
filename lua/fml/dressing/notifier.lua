vim.notify = eve.notifier

ark.fn.observe({ dot.status.notification_level, dot.status.notification_paused }, function()
  eve.notifier.schedule()
end)
