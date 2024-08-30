---@alias fml.types.ui.select.IFetchData
---| fun(force: boolean): fml.types.ui.select.IData

---@alias fml.types.ui.select.IFetchPreviewData
---| fun(item: fml.types.ui.select.IItem): fml.ui.search.preview.IData|nil

---@alias fml.types.ui.select.IPatchPreviewData
---| fun(item: fml.types.ui.select.IItem, last_item: fml.types.ui.select.IItem, last_data: fml.ui.search.preview.IData): fml.ui.search.preview.IData

---@alias fml.types.ui.select.IMatchedItemCmp
---| fun(item1: fml.types.ui.select.IMatchedItem, item2: fml.types.ui.select.IMatchedItem): boolean

---@alias fml.types.ui.select.IRenderItem
---| fun(item: fml.types.ui.select.IItem, match: fml.types.ui.select.IMatchedItem): string, fml.types.ui.IInlineHighlight[]

---@alias fml.types.ui.select.IOnConfirm
---| fun(item: fml.types.ui.select.IItem): boolean

---@class fml.types.ui.select.IData
---@field public items                  fml.types.ui.select.IItem[]
---@field public cursor_uuid            ?string
---@field public present_uuid           ?string

---@class fml.types.ui.select.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string|nil
---@field public data                   any|nil

---@class fml.types.ui.select.IMatchedItem
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                fml.types.IMatchPoint[]

---@class fml.types.ui.select.IProvider
---@field public fetch_data             fml.types.ui.select.IFetchData
---@field public fetch_preview_data     ?fml.types.ui.select.IFetchPreviewData
---@field public patch_preview_data     ?fml.types.ui.select.IPatchPreviewData
---@field public render_item            ?fml.types.ui.select.IRenderItem

---@class fml.types.ui.ISelect
---@field public change_dimension       fun(self: fml.types.ui.ISelect, dimension: fml.types.ui.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.types.ui.ISelect, title: string): nil
---@field public change_preview_title   fun(self: fml.types.ui.ISelect, title: string): nil
---@field public close                  fun(self: fml.types.ui.ISelect): nil
---@field public focus                  fun(self: fml.types.ui.ISelect): nil
---@field public get_item               fun(self: fml.types.ui.ISelect, uuid: string): fml.types.ui.select.IItem|nil
---@field public get_matched_items      fun(self: fml.types.ui.ISelect): fml.types.ui.select.IMatchedItem[]
---@field public get_winnr_input        fun(self: fml.types.ui.ISelect): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.ISelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.types.ui.ISelect): integer|nil
---@field public mark_data_dirty        fun(self: fml.types.ui.ISelect): nil
---@field public open                   fun(self: fml.types.ui.ISelect): nil
---@field public toggle                 fun(self: fml.types.ui.ISelect): nil
