local f = function(delay, group, level, title, content, timeout)
  if delay == 0 then
    eve.notifier.notify({
      group = group,
      level = level,
      title = title,
      content = content,
      timeout = timeout,
      anonymous = false,
      silent = false,
    })
  else
    eve.std.timer.set_timeout(function()
      eve.notifier.notify({
        group = group,
        level = level,
        title = title,
        content = content,
        timeout = timeout,
        anonymous = false,
        silent = false,
      })
    end, delay)
  end
end

f(0, nil, "TRACE", "wulala__trace", "This is a trace message", 3000)
f(0, nil, "DEBUG", "wulala__debug", "This is a debug message", 3000)
f(0, "wulala", "INFO", "wulala__info", "This is a info message", 3000)
f(0, nil, "WARN", "wulala__warn", "This is a warn message", 3000)
f(0, nil, "ERROR", "wulala__error", "This is a error message", 3000)
f(500, nil, "TRACE", "wulala__trace2", "This is a trace message", 3000)
f(500, nil, "DEBUG", "wulala__debug2", "This is a debug message", 3000)
f(500, "wulala", "INFO", "wulala__info2", "This is a info message", 3000)
f(500, nil, "WARN", "wulala__warn2", "This is a warn message", 3000)
f(500, nil, "ERROR", "wulala__error2", "This is a error message", 3000)
f(2000, nil, "TRACE", "wulala__trace3", "This is a trace message", 3000)
f(2000, nil, "DEBUG", "wulala__debug3", "This is a debug message", 3000)
f(2000, "wulala", "INFO", "wulala__info3", "This is a info message", 3000)
f(2000, nil, "WARN", "wulala__warn3", "This is a warn message", 3000)
f(2000, nil, "ERROR", "wulala__error3", "This is a error message", 3000)

f(2500, "wulala", "ERROR", "wulala__info error", "This is a info (x) error message", 3000)
