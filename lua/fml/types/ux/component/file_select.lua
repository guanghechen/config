---@class fml.t.ux.IFileSelect
---@field public change_dimension       fun(self: fml.t.ux.IFileSelect, dimension: fml.t.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.t.ux.IFileSelect, title: string): nil
---@field public change_preview_title   fun(self: fml.t.ux.IFileSelect, title: string): nil
---@field public close                  fun(self: fml.t.ux.IFileSelect): nil
---@field public focus                  fun(self: fml.t.ux.IFileSelect): nil
---@field public get_item               fun(self: fml.t.ux.IFileSelect, uuid: string): fml.t.ux.select.IItem|nil
---@field public get_matched_items      fun(self: fml.t.ux.IFileSelect): fml.t.ux.select.IMatchedItem[]
---@field public get_winnr_input        fun(self: fml.t.ux.IFileSelect): integer|nil
---@field public get_winnr_main         fun(self: fml.t.ux.IFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.t.ux.IFileSelect): integer|nil
---@field public mark_data_dirty        fun(self: fml.t.ux.IFileSelect): nil
---@field public open                   fun(self: fml.t.ux.IFileSelect): nil
---@field public toggle                 fun(self: fml.t.ux.IFileSelect): nil

---@alias fml.t.ux.file_select.IFetchData
---| fun(force: boolean): fml.t.ux.file_select.IData

---@alias fml.t.ux.file_select.IFetchPreviewData
---| fun(item: fml.t.ux.file_select.IItem): fml.t.ux.search.preview.IData|nil

---@alias fml.t.ux.file_select.IPatchPreviewData
---| fun(item: fml.t.ux.file_select.IItem, last_item: fml.t.ux.file_select.IItem, last_data: fml.t.ux.search.preview.IData): fml.t.ux.search.preview.IData

---@alias fml.t.ux.file_select.IRenderItem
---| fun(item: fml.t.ux.file_select.IItem, match: fml.t.ux.select.IMatchedItem): string, eve.t.IHighlightInline[]

---@class fml.t.ux.file_select.IData
---@field public cwd                    string
---@field public items                  fml.t.ux.file_select.IRawItem[]
---@field public present_uuid           ?string

---@class fml.t.ux.file_select.IRawItem
---
---@field public filepath               string
---@field public group                  ?string
---@field public uuid                   ?string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.t.ux.file_select.IItemData
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.t.ux.file_select.IItem : fml.t.ux.select.IItem
---@field public data                   fml.t.ux.file_select.IItemData

---@class fml.t.ux.file_select.IProvider
---@field public fetch_data             fml.t.ux.file_select.IFetchData
---@field public fetch_preview_data     ?fml.t.ux.file_select.IFetchPreviewData
---@field public patch_preview_data     ?fml.t.ux.file_select.IPatchPreviewData
---@field public render_item            ?fml.t.ux.file_select.IRenderItem
