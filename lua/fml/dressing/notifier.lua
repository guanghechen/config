vim.notify = era.notifier

ark.fn.observe({ era.state.status.notification_level, era.state.status.notification_paused }, function()
  era.notifier.schedule()
end)
