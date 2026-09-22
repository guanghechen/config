---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.surrounds.types" ---@type string

---@class era.keystroke.surrounds.IPosition
---@field public line                   integer                       1-based line
---@field public col                    integer                       1-based byte column

---@class era.keystroke.surrounds.IRegion
---@field public from                   era.keystroke.surrounds.IPosition
---@field public to                     ?era.keystroke.surrounds.IPosition Inclusive; nil denotes an empty region

---@class era.keystroke.surrounds.IRegionPair
---@field public left                   era.keystroke.surrounds.IRegion
---@field public right                  era.keystroke.surrounds.IRegion

---@class era.keystroke.surrounds.ISpan
---@field public from                   integer
---@field public to                     integer                       End-exclusive

---@class era.keystroke.surrounds.ISpanPair
---@field public left                   era.keystroke.surrounds.ISpan
---@field public right                  era.keystroke.surrounds.ISpan

---@class era.keystroke.surrounds.IMarks
---@field public first                  era.keystroke.surrounds.IPosition
---@field public second                 era.keystroke.surrounds.IPosition
---@field public selection_type         "charwise"|"linewise"|"blockwise"

---@class era.keystroke.surrounds.IInputDefinition
---@field public id                     string
---@field public patterns               table

---@class era.keystroke.surrounds.IOutputDefinition
---@field public left                   string
---@field public right                  string
---@field public did_count              ?boolean

---@class era.keystroke.surrounds.ISearchOptions
---@field public n_lines                integer
---@field public n_times                integer
---@field public reference_region       era.keystroke.surrounds.IRegion

---@class era.keystroke.surrounds.INeighborhood
---@field public n_neighbors            integer
---@field public text                   string
---@field public lines                  string[]
---@field public region_to_span         fun(region: era.keystroke.surrounds.IRegion): era.keystroke.surrounds.ISpan
---@field public span_to_region         fun(span: era.keystroke.surrounds.ISpan): era.keystroke.surrounds.IRegion

return {}
