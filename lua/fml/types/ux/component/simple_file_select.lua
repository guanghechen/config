---@class t.fml.ux.ISimpleFileSelect
---@field public change_dimension       fun(self: t.fml.ux.ISimpleFileSelect, dimension: t.fml.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: t.fml.ux.ISimpleFileSelect, title: string): nil
---@field public change_preview_title   fun(self: t.fml.ux.ISimpleFileSelect, title: string): nil
---@field public close                  fun(self: t.fml.ux.ISimpleFileSelect): nil
---@field public focus                  fun(self: t.fml.ux.ISimpleFileSelect): nil
---@field public get_file_select        fun(self: t.fml.ux.ISimpleFileSelect): t.fml.ux.IFileSelect
---@field public get_winnr_input        fun(self: t.fml.ux.ISimpleFileSelect): integer|nil
---@field public get_winnr_main         fun(self: t.fml.ux.ISimpleFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: t.fml.ux.ISimpleFileSelect): integer|nil
---@field public mark_data_dirty        fun(self: t.fml.ux.ISimpleFileSelect): integer|nil
---@field public open                   fun(self: t.fml.ux.ISimpleFileSelect): nil

---@class t.fml.ux.simple_file_select.IData
---@field public cwd                    string
---@field public filepaths              string[]
---@field public present_filepath       ?string

---@class t.fml.ux.simple_file_select.IProvider
---@field public provide                fun(force: boolean): t.fml.ux.simple_file_select.IData
