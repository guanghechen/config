vim.notify = eve.notifier

ark.fn.observe({ dot.state.status.notification_level, dot.state.status.notification_paused }, function()
  eve.notifier.schedule()
end)
