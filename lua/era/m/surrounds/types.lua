---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.surrounds.types" ---@type string

---@class era.m.surrounds.IPosition
---@field public line                   integer                       1-based line
---@field public col                    integer                       1-based byte column

---@class era.m.surrounds.IRegion
---@field public from                   era.m.surrounds.IPosition
---@field public to                     ?era.m.surrounds.IPosition Inclusive; nil denotes an empty region

---@class era.m.surrounds.IRegionPair
---@field public left                   era.m.surrounds.IRegion
---@field public right                  era.m.surrounds.IRegion

---@class era.m.surrounds.ISpan
---@field public from                   integer
---@field public to                     integer                       End-exclusive

---@class era.m.surrounds.ISpanPair
---@field public left                   era.m.surrounds.ISpan
---@field public right                  era.m.surrounds.ISpan

---@class era.m.surrounds.IMarks
---@field public first                  era.m.surrounds.IPosition
---@field public second                 era.m.surrounds.IPosition
---@field public selection_type         "charwise"|"linewise"|"blockwise"

---@class era.m.surrounds.IInputDefinition
---@field public id                     string
---@field public patterns               table

---@class era.m.surrounds.IOutputDefinition
---@field public left                   string
---@field public right                  string
---@field public did_count              ?boolean

---@class era.m.surrounds.ISearchOptions
---@field public n_lines                integer
---@field public n_times                integer
---@field public reference_region       era.m.surrounds.IRegion

---@class era.m.surrounds.INeighborhood
---@field public n_neighbors            integer
---@field public text                   string
---@field public lines                  string[]
---@field public region_to_span         fun(region: era.m.surrounds.IRegion): era.m.surrounds.ISpan
---@field public span_to_region         fun(span: era.m.surrounds.ISpan): era.m.surrounds.IRegion

return {}
