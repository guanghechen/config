vim.notify = eve.notifier

std.fn.observe({ dot.status.notification_level, dot.status.notification_paused }, function()
  eve.notifier.schedule()
end)
