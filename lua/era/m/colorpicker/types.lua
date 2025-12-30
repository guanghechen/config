---@meta

---@alias era.m.colorpicker.InputModeName
---| "HEX"
---| "RGB"
---| "HSL"
---| "HSV"

---@alias era.m.colorpicker.OutputModeName
---| "HEX"
---| "RGB"
---| "HSL"
---| "HSV"

---@alias era.m.colorpicker.PointType
---| "color"
---| "alpha"
---| "none"

---@class era.m.colorpicker.IPoint
---@field public type                   era.m.colorpicker.PointType
---@field public index                  integer|nil

---@class era.m.colorpicker.IInputMode
---@field public name                   era.m.colorpicker.InputModeName
---@field public bar_name               string[]
---@field public max                    integer[]
---@field public from_rgb               fun(r: integer, g: integer, b: integer): integer[]
---@field public to_rgb                 fun(value: integer[]): integer, integer, integer

---@class era.m.colorpicker.IOutputMode
---@field public name                   era.m.colorpicker.OutputModeName
---@field public str                    fun(r: integer, g: integer, b: integer, alpha: integer|nil): string

---@class era.m.colorpicker.IPickResult
---@field public start_col              integer
---@field public end_col                integer
---@field public r                      integer
---@field public g                      integer
---@field public b                      integer
---@field public alpha                  integer|nil
