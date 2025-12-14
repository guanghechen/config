---@meta

---@alias dot.ux.widget.colorpicker.InputModeName
---| "HEX"
---| "RGB"
---| "HSL"
---| "HSV"

---@alias dot.ux.widget.colorpicker.OutputModeName
---| "HEX"
---| "RGB"
---| "HSL"
---| "HSV"

---@alias dot.ux.widget.colorpicker.PointType
---| "color"
---| "alpha"
---| "none"

---@class dot.ux.widget.colorpicker.IPoint
---@field public type                   dot.ux.widget.colorpicker.PointType
---@field public index                  integer|nil

---@class dot.ux.widget.colorpicker.IInputMode
---@field public name                   dot.ux.widget.colorpicker.InputModeName
---@field public bar_name               string[]
---@field public max                    integer[]
---@field public from_rgb               fun(r: integer, g: integer, b: integer): integer[]
---@field public to_rgb                 fun(value: integer[]): integer, integer, integer

---@class dot.ux.widget.colorpicker.IOutputMode
---@field public name                   dot.ux.widget.colorpicker.OutputModeName
---@field public str                    fun(r: integer, g: integer, b: integer, alpha: integer|nil): string

---@class dot.ux.widget.colorpicker.IPickResult
---@field public start_col              integer
---@field public end_col                integer
---@field public r                      integer
---@field public g                      integer
---@field public b                      integer
---@field public alpha                  integer|nil
