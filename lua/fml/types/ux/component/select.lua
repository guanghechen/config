---@class t.fml.ux.ISelect
---@field public change_dimension       fun(self: t.fml.ux.ISelect, dimension: t.fml.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: t.fml.ux.ISelect, title: string): nil
---@field public change_preview_title   fun(self: t.fml.ux.ISelect, title: string): nil
---@field public close                  fun(self: t.fml.ux.ISelect): nil
---@field public focus                  fun(self: t.fml.ux.ISelect): nil
---@field public get_item               fun(self: t.fml.ux.ISelect, uuid: string): t.fml.ux.select.IItem|nil
---@field public get_matched_items      fun(self: t.fml.ux.ISelect): t.fml.ux.select.IMatchedItem[]
---@field public get_winnr_input        fun(self: t.fml.ux.ISelect): integer|nil
---@field public get_winnr_main         fun(self: t.fml.ux.ISelect): integer|nil
---@field public get_winnr_preview      fun(self: t.fml.ux.ISelect): integer|nil
---@field public mark_data_dirty        fun(self: t.fml.ux.ISelect): nil
---@field public open                   fun(self: t.fml.ux.ISelect): nil
---@field public toggle                 fun(self: t.fml.ux.ISelect): nil

---@alias t.fml.ux.select.IFetchData
---| fun(force: boolean): t.fml.ux.select.IData

---@alias t.fml.ux.select.IFetchPreviewData
---| fun(item: t.fml.ux.select.IItem): t.fml.ux.search.preview.IData|nil

---@alias t.fml.ux.select.IPatchPreviewData
---| fun(item: t.fml.ux.select.IItem, last_item: t.fml.ux.select.IItem, last_data: t.fml.ux.search.preview.IData): t.fml.ux.search.preview.IData

---@alias t.fml.ux.select.IMatchedItemCmp
---| fun(item1: t.fml.ux.select.IMatchedItem, item2: t.fml.ux.select.IMatchedItem): boolean

---@alias t.fml.ux.select.IRenderItem
---| fun(item: t.fml.ux.select.IItem, match: t.fml.ux.select.IMatchedItem): string, t.eve.IHighlightInline[]

---@alias t.fml.ux.select.IOnConfirm
---| fun(item: t.fml.ux.select.IItem): t.eve.e.WidgetConfirmAction|nil

---@class t.fml.ux.select.IData
---@field public items                  t.fml.ux.select.IItem[]
---@field public cursor_uuid            ?string
---@field public present_uuid           ?string

---@class t.fml.ux.select.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string|nil
---@field public data                   any|nil

---@class t.fml.ux.select.IMatchedItem
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                t.eve.IMatchPoint[]

---@class t.fml.ux.select.IProvider
---@field public fetch_data             t.fml.ux.select.IFetchData
---@field public fetch_preview_data     ?t.fml.ux.select.IFetchPreviewData
---@field public patch_preview_data     ?t.fml.ux.select.IPatchPreviewData
---@field public render_item            ?t.fml.ux.select.IRenderItem
