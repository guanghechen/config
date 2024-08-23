---@class fml.types.ui.simple_file_select.IData
---@field public cwd                    string
---@field public filepaths              string[]
---@field public present_filepath       ?string

---@class fml.types.ui.simple_file_select.IProvider
---@field public provide                fun(): fml.types.ui.simple_file_select.IData

---@class fml.types.ui.ISimpleFileSelect
---@field public change_dimension       fun(self: fml.types.ui.ISimpleFileSelect, dimension: fml.types.ui.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.types.ui.ISimpleFileSelect, title: string): nil
---@field public change_preview_title   fun(self: fml.types.ui.ISimpleFileSelect, title: string): nil
---@field public get_file_select        fun(self: fml.types.ui.ISimpleFileSelect): fml.types.ui.IFileSelect
---@field public get_winnr_input        fun(self: fml.types.ui.ISimpleFileSelect): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.ISimpleFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.types.ui.ISimpleFileSelect): integer|nil
---@field public list                   fun(self: fml.types.ui.ISimpleFileSelect): nil
