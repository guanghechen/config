---@class fml.types.ui.fast_file_select.IData
---@field public cwd                    string
---@field public filepaths              string[]

---@class fml.types.ui.fast_file_select.IProvider
---@field public provide                fun(): fml.types.ui.fast_file_select.IData

---@class fml.types.ui.IFastFileSelect
---@field public change_input_title     fun(self: fml.types.ui.IFastFileSelect, title: string): nil
---@field public change_preview_title   fun(self: fml.types.ui.IFastFileSelect, title: string): nil
---@field public get_file_select        fun(self: fml.types.ui.IFastFileSelect): fml.types.ui.IFileSelect
---@field public list                   fun(self: fml.types.ui.IFastFileSelect): nil
