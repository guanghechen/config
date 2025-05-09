vim.notify = eve.notifier

eve.fn.observe({ eve.status.notification_level, eve.status.notification_paused }, function()
  eve.notifier.schedule()
end)
