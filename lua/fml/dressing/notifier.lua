vim.notify = eve.notifier

std.fn.observe({ std.status.notification_level, std.status.notification_paused }, function()
  eve.notifier.schedule()
end)
