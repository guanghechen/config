eve.notifier.trace(nil, "wulala__trace", "This is a trace message", 3000)
eve.notifier.debug(nil, "wulala__debug", "This is a debug message", 3000)
eve.notifier.info("wulala", "wulala__info", "This is a info message", 3000)
eve.notifier.warn(nil, "wulala__warn", "This is a warn message", 3000)
eve.notifier.error(nil, "wulala__error", "This is a error message", 3000)

vim.defer_fn(function()
  eve.notifier.error("wulala", "wulala__info error", "This is a info (x) error message", 3000)
end, 2000)
