---@alias fml.types.ui.search.IOnClose
---| fun(): nil

---@alias fml.types.ui.search.IOnConfirm
---| fun(item: fml.types.ui.search.IItem): boolean

---@alias fml.types.ui.search.main.IOnRendered
---| fun(): nil

---@alias fml.types.ui.search.preview.IOnRendered
---| fun(): nil

---@alias fml.types.ui.search.preview.IFetchData
---| fun(item: fml.types.ui.search.IItem): fml.ui.search.preview.IData

---@alias fml.types.ui.search.preview.IPatchData
---| fun(item: fml.types.ui.search.IItem, last_item: fml.types.ui.search.IItem, last_data: fml.ui.search.preview.IData): fml.ui.search.preview.IData

---@alias fml.types.ui.search.IFetchItemsCallback
---| fun(ok: true, items: fml.types.ui.search.IItem[]|nil): nil
---| fun(ok: false, error: string|nil): nil

---@alias fml.types.ui.search.IFetchItems
---| fun(input: string, callback: fml.types.ui.search.IFetchItemsCallback): nil

---@class fml.types.ui.search.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             fml.types.ui.IInlineHighlight[]

---@class fml.ui.search.preview.IData
---@field public lines                  string[]
---@field public highlights             fml.types.ui.IHighlight[]
---@field public filetype               string|nil
---@field public show_numbers           boolean
---@field public title                  string
---@field public lnum                   integer|nil
---@field public col                    integer|nil

---@class fml.ui.search.preview.IWinOpts
---@field public title                  string
---@field public show_numbers           boolean
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.types.ui.search.IState
---@field public uuid                   string
---@field public title                  string
---@field public items                  fml.types.ui.search.IItem[]
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public visible                fml.types.collection.IObservable
---@field public dirty_items            fml.types.collection.IObservable
---@field public dirty_main             fml.types.collection.IObservable
---@field public dirty_preview          fml.types.collection.IObservable
---@field public max_width              integer
---@field public get_current            fun(self: fml.types.ui.search.IState): fml.types.ui.search.IItem|nil, integer, string|nil
---@field public locate                 fun(self: fml.types.ui.search.IState, lnum: integer): integer
---@field public mark_dirty             fun(self: fml.types.ui.search.IState): nil
---@field public moveup                 fun(self: fml.types.ui.search.IState): integer
---@field public movedown               fun(self: fml.types.ui.search.IState): integer

---@class fml.types.ui.search.IInput
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IInput): integer
---@field public destroy                fun(self: fml.types.ui.search.IInput): nil
---@field public reset_input            fun(self: fml.types.ui.search.IInput, input?: string): nil

---@class fml.types.ui.search.IMain
---@field public state                  fml.types.ui.search.IState
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IMain): integer
---@field public destroy                fun(self: fml.types.ui.search.IMain): nil
---@field public place_lnum_sign        fun(self: fml.types.ui.search.IMain): integer|nil
---@field public render                 fun(self: fml.types.ui.search.IMain, force?: boolean): nil

---@class fml.types.ui.search.IPreview
---@field public state                  fml.types.ui.search.IState
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IPreview): integer
---@field public destroy                fun(self: fml.types.ui.search.IPreview): nil
---@field public render                 fun(self: fml.types.ui.search.IPreview, force?: boolean): nil

---@class fml.types.ui.search.ISearch
---@field public state                  fml.types.ui.search.IState
---@field public get_winnr_input        fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public get_winnr_preview      fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public close                  fun(self: fml.types.ui.search.ISearch): nil
---@field public focus                  fun(self: fml.types.ui.search.ISearch): nil
---@field public open                   fun(self: fml.types.ui.search.ISearch): nil
---@field public toggle                 fun(self: fml.types.ui.search.ISearch): nil
