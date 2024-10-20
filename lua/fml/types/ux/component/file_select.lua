---@class t.fml.ux.IFileSelect
---@field public change_dimension       fun(self: t.fml.ux.IFileSelect, dimension: t.fml.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: t.fml.ux.IFileSelect, title: string): nil
---@field public change_preview_title   fun(self: t.fml.ux.IFileSelect, title: string): nil
---@field public close                  fun(self: t.fml.ux.IFileSelect): nil
---@field public focus                  fun(self: t.fml.ux.IFileSelect): nil
---@field public get_item               fun(self: t.fml.ux.IFileSelect, uuid: string): t.fml.ux.select.IItem|nil
---@field public get_matched_items      fun(self: t.fml.ux.IFileSelect): t.fml.ux.select.IMatchedItem[]
---@field public get_winnr_input        fun(self: t.fml.ux.IFileSelect): integer|nil
---@field public get_winnr_main         fun(self: t.fml.ux.IFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: t.fml.ux.IFileSelect): integer|nil
---@field public mark_data_dirty        fun(self: t.fml.ux.IFileSelect): nil
---@field public open                   fun(self: t.fml.ux.IFileSelect): nil
---@field public toggle                 fun(self: t.fml.ux.IFileSelect): nil

---@alias t.fml.ux.file_select.IFetchData
---| fun(force: boolean): t.fml.ux.file_select.IData

---@alias t.fml.ux.file_select.IFetchPreviewData
---| fun(item: t.fml.ux.file_select.IItem): t.fml.ux.search.preview.IData|nil

---@alias t.fml.ux.file_select.IPatchPreviewData
---| fun(item: t.fml.ux.file_select.IItem, last_item: t.fml.ux.file_select.IItem, last_data: t.fml.ux.search.preview.IData): t.fml.ux.search.preview.IData

---@alias t.fml.ux.file_select.IRenderItem
---| fun(item: t.fml.ux.file_select.IItem, match: t.fml.ux.select.IMatchedItem): string, t.eve.IHighlightInline[]

---@class t.fml.ux.file_select.IData
---@field public cwd                    string
---@field public items                  t.fml.ux.file_select.IRawItem[]
---@field public present_uuid           ?string

---@class t.fml.ux.file_select.IRawItem
---
---@field public filepath               string
---@field public group                  ?string
---@field public uuid                   ?string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class t.fml.ux.file_select.IItemData
---@field public filepath               string
---@field public filename               string
---@field public icon                   string
---@field public icon_hl                string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class t.fml.ux.file_select.IItem : t.fml.ux.select.IItem
---@field public data                   t.fml.ux.file_select.IItemData

---@class t.fml.ux.file_select.IProvider
---@field public fetch_data             t.fml.ux.file_select.IFetchData
---@field public fetch_preview_data     ?t.fml.ux.file_select.IFetchPreviewData
---@field public patch_preview_data     ?t.fml.ux.file_select.IPatchPreviewData
---@field public render_item            ?t.fml.ux.file_select.IRenderItem
