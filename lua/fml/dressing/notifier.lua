vim.notify = eve.notifier
-- Override vim.print to prevent blink.cmp errors from being printed at cursor position
-- Error code 11 (EAGAIN) from filesystem operations should be logged, not printed
do
  local original_vim_print = vim.print
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.print = function(...)
    local args = { ... }
    local message = table.concat(vim.tbl_map(tostring, args), "\t")

    -- Detect blink.cmp error messages and redirect to notifier
    if message:match("^failed") then
      -- Use WARN level for failed operations
      eve.notifier(message, vim.log.levels.WARN)
    else
      -- For other messages, use the original vim.print
      original_vim_print(...)
    end
  end
end

std.fn.observe({ eve.status.notification_level, eve.status.notification_paused }, function()
  eve.notifier.schedule()
end)
