vim.notify = eve.notifier

eve.state.observe({ eve.status.notification_level, eve.status.notification_paused }, function()
  eve.notifier.schedule()
end)
