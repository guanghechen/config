---@class fml.t.ux.ISimpleFileSelect
---@field public change_dimension       fun(self: fml.t.ux.ISimpleFileSelect, dimension: fml.t.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.t.ux.ISimpleFileSelect, title: string): nil
---@field public change_preview_title   fun(self: fml.t.ux.ISimpleFileSelect, title: string): nil
---@field public close                  fun(self: fml.t.ux.ISimpleFileSelect): nil
---@field public focus                  fun(self: fml.t.ux.ISimpleFileSelect): nil
---@field public get_file_select        fun(self: fml.t.ux.ISimpleFileSelect): fml.t.ux.IFileSelect
---@field public get_winnr_input        fun(self: fml.t.ux.ISimpleFileSelect): integer|nil
---@field public get_winnr_main         fun(self: fml.t.ux.ISimpleFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.t.ux.ISimpleFileSelect): integer|nil
---@field public mark_data_dirty        fun(self: fml.t.ux.ISimpleFileSelect): integer|nil
---@field public open                   fun(self: fml.t.ux.ISimpleFileSelect): nil

---@class fml.t.ux.simple_file_select.IData
---@field public cwd                    string
---@field public filepaths              string[]
---@field public present_filepath       ?string

---@class fml.t.ux.simple_file_select.IProvider
---@field public provide                fun(force: boolean): fml.t.ux.simple_file_select.IData
