local Trace = require("__test__.support.cmp.behavior_trace")
local t = require("__test__.support.harness").new()

Trace.check(t, require("__test__.fixtures.era.keystroke.cmp.behavior.insert"))

t:run()
