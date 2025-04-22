local f = function(delay, ...)
  local args = { ... }
  if delay == 0 then
    eve.notifier.notify(unpack(args))
  else
    vim.defer_fn(function()
      eve.notifier.notify(unpack(args))
    end, delay)
  end
end

f(0, "TRACE", nil, "wulala__trace", "This is a trace message", 3000, false, false)
f(0, "DEBUG", nil, "wulala__debug", "This is a debug message", 3000, false, false)
f(0, "INFO", "wulala", "wulala__info", "This is a info message", 3000, false, false)
f(0, "WARN", nil, "wulala__warn", "This is a warn message", 3000, false, false)
f(0, "ERROR", nil, "wulala__error", "This is a error message", 3000, false, false)
f(500, "TRACE", nil, "wulala__trace2", "This is a trace message", 3000, false, false)
f(500, "DEBUG", nil, "wulala__debug2", "This is a debug message", 3000, false, false)
f(500, "INFO", "wulala", "wulala__info2", "This is a info message", 3000, false, false)
f(500, "WARN", nil, "wulala__warn2", "This is a warn message", 3000, false, false)
f(500, "ERROR", nil, "wulala__error2", "This is a error message", 3000, false, false)
f(2000, "TRACE", nil, "wulala__trace3", "This is a trace message", 3000, false, false)
f(2000, "DEBUG", nil, "wulala__debug3", "This is a debug message", 3000, false, false)
f(2000, "INFO", "wulala", "wulala__info3", "This is a info message", 3000, false, false)
f(2000, "WARN", nil, "wulala__warn3", "This is a warn message", 3000, false, false)
f(2000, "ERROR", nil, "wulala__error3", "This is a error message", 3000, false, false)

f(2500, "ERROR", "wulala", "wulala__info error", "This is a info (x) error message", 3000, false, false)
