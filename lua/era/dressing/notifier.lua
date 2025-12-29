vim.notify = dot.notifier

stl.fn.observe({ dot.state.status.notification_level, dot.state.status.notification_paused }, function()
  dot.notifier.schedule()
end)
