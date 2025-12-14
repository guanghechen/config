vim.notify = era.notifier

ark.fn.observe({ dot.state.status.notification_level, dot.state.status.notification_paused }, function()
  era.notifier.schedule()
end)
