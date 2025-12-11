vim.notify = eve.notifier

ark.fn.observe({ era.state.status.notification_level, era.state.status.notification_paused }, function()
  eve.notifier.schedule()
end)
