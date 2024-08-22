---@alias fml.types.ui.file_select.IFetchData
---| fun(): fml.types.ui.file_select.IData

---@alias fml.types.ui.file_select.IFetchPreviewData
---| fun(item: fml.types.ui.file_select.IItem): fml.ui.search.preview.IData|nil

---@alias fml.types.ui.file_select.IPatchPreviewData
---| fun(item: fml.types.ui.file_select.IItem, last_item: fml.types.ui.file_select.IItem, last_data: fml.ui.search.preview.IData): fml.ui.search.preview.IData

---@alias fml.types.ui.file_select.IRenderItem
---| fun(item: fml.types.ui.file_select.IItem, match: fml.types.ui.select.IMatchedItem): string, fml.types.ui.IInlineHighlight[]

---@class fml.types.ui.file_select.IData
---@field public cwd                    string
---@field public items                  fml.types.ui.file_select.IRawItem[]
---@field public present_uuid           ?string

---@class fml.types.ui.file_select.IRawItem
---@field public filepath               string
---@field public uuid                   ?string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.types.ui.file_select.IItemData
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.types.ui.file_select.IItem : fml.types.ui.select.IItem
---@field public data                   fml.types.ui.file_select.IItemData

---@class fml.types.ui.file_select.IProvider
---@field public fetch_data             fml.types.ui.file_select.IFetchData
---@field public fetch_preview_data     ?fml.types.ui.file_select.IFetchPreviewData
---@field public patch_preview_data     ?fml.types.ui.file_select.IPatchPreviewData
---@field public render_item            ?fml.types.ui.file_select.IRenderItem

---@class fml.types.ui.IFileSelect
---@field public state                  fml.types.ui.search.IState
---@field public get_winnr_input        fun(self: fml.types.ui.IFileSelect): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.IFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.types.ui.IFileSelect): integer|nil
---@field public change_input_title     fun(self: fml.types.ui.IFileSelect, title: string): nil
---@field public change_preview_title   fun(self: fml.types.ui.IFileSelect, title: string): nil
---@field public mark_data_dirty        fun(self: fml.types.ui.IFileSelect): nil
---@field public open_filepath          fun(self: fml.types.ui.IFileSelect, filepath: string): nil
---@field public close                  fun(self: fml.types.ui.IFileSelect): nil
---@field public focus                  fun(self: fml.types.ui.IFileSelect): nil
---@field public open                   fun(self: fml.types.ui.IFileSelect): nil
---@field public toggle                 fun(self: fml.types.ui.IFileSelect): nil
