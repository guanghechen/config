---@meta

---@alias dot.module.colorpicker.InputModeName
---| "HEX"
---| "RGB"
---| "HSL"
---| "HSV"

---@alias dot.module.colorpicker.OutputModeName
---| "HEX"
---| "RGB"
---| "HSL"
---| "HSV"

---@alias dot.module.colorpicker.PointType
---| "color"
---| "alpha"
---| "none"

---@class dot.module.colorpicker.IPoint
---@field public type                   dot.module.colorpicker.PointType
---@field public index                  integer|nil

---@class dot.module.colorpicker.IInputMode
---@field public name                   dot.module.colorpicker.InputModeName
---@field public bar_name               string[]
---@field public max                    integer[]
---@field public from_rgb               fun(r: integer, g: integer, b: integer): integer[]
---@field public to_rgb                 fun(value: integer[]): integer, integer, integer

---@class dot.module.colorpicker.IOutputMode
---@field public name                   dot.module.colorpicker.OutputModeName
---@field public str                    fun(r: integer, g: integer, b: integer, alpha: integer|nil): string

---@class dot.module.colorpicker.IPickResult
---@field public start_col              integer
---@field public end_col                integer
---@field public r                      integer
---@field public g                      integer
---@field public b                      integer
---@field public alpha                  integer|nil
