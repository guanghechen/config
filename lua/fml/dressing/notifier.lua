vim.notify = eve.notifier

eve.state.observe({ eve.state.status.notification_level, eve.state.status.notification_paused }, function()
  eve.notifier.schedule()
end)
