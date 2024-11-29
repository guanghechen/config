---@class fml.t.ux.ISelect
---@field public change_dimension       fun(self: fml.t.ux.ISelect, dimension: fml.t.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.t.ux.ISelect, title: string): nil
---@field public change_preview_title   fun(self: fml.t.ux.ISelect, title: string): nil
---@field public close                  fun(self: fml.t.ux.ISelect): nil
---@field public focus                  fun(self: fml.t.ux.ISelect): nil
---@field public get_item               fun(self: fml.t.ux.ISelect, uuid: string): fml.t.ux.select.IItem|nil
---@field public get_matched_items      fun(self: fml.t.ux.ISelect): fml.t.ux.select.IMatchedItem[]
---@field public get_winnr_input        fun(self: fml.t.ux.ISelect): integer|nil
---@field public get_winnr_main         fun(self: fml.t.ux.ISelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.t.ux.ISelect): integer|nil
---@field public mark_data_dirty        fun(self: fml.t.ux.ISelect): nil
---@field public open                   fun(self: fml.t.ux.ISelect): nil
---@field public toggle                 fun(self: fml.t.ux.ISelect): nil

---@alias fml.t.ux.select.IFetchData
---| fun(force: boolean): fml.t.ux.select.IData

---@alias fml.t.ux.select.IFetchPreviewData
---| fun(item: fml.t.ux.select.IItem): fml.t.ux.search.preview.IData|nil

---@alias fml.t.ux.select.IPatchPreviewData
---| fun(item: fml.t.ux.select.IItem, last_item: fml.t.ux.select.IItem, last_data: fml.t.ux.search.preview.IData): fml.t.ux.search.preview.IData

---@alias fml.t.ux.select.IMatchedItemCmp
---| fun(item1: fml.t.ux.select.IMatchedItem, item2: fml.t.ux.select.IMatchedItem): boolean

---@alias fml.t.ux.select.IRenderItem
---| fun(item: fml.t.ux.select.IItem, match: fml.t.ux.select.IMatchedItem): string, eve.t.IHighlightInline[]

---@alias fml.t.ux.select.IOnConfirm
---| fun(item: fml.t.ux.select.IItem): eve.e.WidgetConfirmAction|nil

---@class fml.t.ux.select.IData
---@field public items                  fml.t.ux.select.IItem[]
---@field public cursor_uuid            ?string
---@field public present_uuid           ?string

---@class fml.t.ux.select.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string|nil
---@field public data                   any|nil

---@class fml.t.ux.select.IMatchedItem
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                eve.t.IMatchPoint[]

---@class fml.t.ux.select.IProvider
---@field public fetch_data             fml.t.ux.select.IFetchData
---@field public fetch_preview_data     ?fml.t.ux.select.IFetchPreviewData
---@field public patch_preview_data     ?fml.t.ux.select.IPatchPreviewData
---@field public render_item            ?fml.t.ux.select.IRenderItem
