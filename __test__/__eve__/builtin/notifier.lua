eve.notifier.notify("TRACE", nil, "wulala__trace", "This is a trace message", 3000, false, false)
eve.notifier.notify("DEBUG", nil, "wulala__debug", "This is a debug message", 3000, false, false)
eve.notifier.notify("INFO", "wulala", "wulala__info", "This is a info message", 3000, false, false)
eve.notifier.notify("WARN", nil, "wulala__warn", "This is a warn message", 3000, false, false)
eve.notifier.notify("ERROR", nil, "wulala__error", "This is a error message", 3000, false, false)

vim.defer_fn(function()
  eve.notifier.notify("ERROR", "wulala", "wulala__info error", "This is a info (x) error message", 3000, false, false)
end, 2000)
