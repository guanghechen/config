---@class fml.types.ui.simple_file_select.IData
---@field public cwd                    string
---@field public filepaths              string[]

---@class fml.types.ui.simple_file_select.IProvider
---@field public provide                fun(): fml.types.ui.simple_file_select.IData

---@class fml.types.ui.ISimpleFileSelect
---@field public change_input_title     fun(self: fml.types.ui.ISimpleFileSelect, title: string): nil
---@field public change_preview_title   fun(self: fml.types.ui.ISimpleFileSelect, title: string): nil
---@field public get_file_select        fun(self: fml.types.ui.ISimpleFileSelect): fml.types.ui.IFileSelect
---@field public list                   fun(self: fml.types.ui.ISimpleFileSelect): nil
