vim.notify = dot.notifier

ark.fn.observe({ dot.state.status.notification_level, dot.state.status.notification_paused }, function()
  dot.notifier.schedule()
end)
