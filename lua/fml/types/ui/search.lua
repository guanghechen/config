---@alias fml.types.ui.search.IOnClose
---| fun(): nil

---@alias fml.types.ui.search.IOnConfirm
---| fun(item: fml.types.ui.search.IItem): boolean

---@alias fml.types.ui.search.IOnMainRendered
---| fun(): nil

---@alias fml.types.ui.search.IOnPreviewRendered
---| fun(): nil

---@alias fml.types.ui.search.IOnResume
---| fun(): nil

---@alias fml.types.ui.search.IFetchPreviewData
---| fun(item: fml.types.ui.search.IItem): fml.ui.search.preview.IData|nil

---@alias fml.types.ui.search.IPatchPreviewData
---| fun(item: fml.types.ui.search.IItem, last_item: fml.types.ui.search.IItem, last_data: fml.ui.search.preview.IData): fml.ui.search.preview.IData

---@alias fml.types.ui.search.IFetchDataCallback
---| fun(ok: true, data: fml.types.ui.search.IData|nil): nil
---| fun(ok: false, error: string|nil): nil

---@alias fml.types.ui.search.IFetchData
---| fun(input: string, callback: fml.types.ui.search.IFetchDataCallback): nil

---@class fml.types.ui.search.IData
---@field public items                  fml.types.ui.search.IItem[]
---@field public present_uuid           ?string

---@class fml.types.ui.search.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             fml.types.ui.IInlineHighlight[]

---@class fml.ui.search.preview.IData
---@field public lines                  string[]
---@field public highlights             fml.types.ui.IHighlight[]
---@field public filetype               string|nil
---@field public title                  string
---@field public lnum                   integer|nil
---@field public col                    integer|nil

---@class fml.types.ui.search.IRawStatuslineItem
---@field public type                   "flag"|"enum"
---@field public desc                   string
---@field public state                  fml.types.collection.IObservable
---@field public symbol                 string
---@field public callback               fun(): nil

---@class fml.types.ui.search.IStatuslineItem
---@field public type                   "flag"|"enum"
---@field public state                  fml.types.collection.IObservable
---@field public symbol                 string
---@field public callback_fn            string

---@class fml.types.ui.search.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class fml.types.ui.search.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public width                  ?number
---@field public width_preview          ?number

---@class fml.types.ui.search.preview.IWinOpts
---@field public title                  string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.types.ui.search.IState
---@field public dirty_items            fml.types.collection.IObservable
---@field public dirty_main             fml.types.collection.IObservable
---@field public dirty_preview          fml.types.collection.IObservable
---@field public enable_multiline_input boolean
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public input_line_count       fml.types.collection.IObservable
---@field public item_present_uuid      string|nil
---@field public items                  fml.types.ui.search.IItem[]
---@field public max_width              integer
---@field public title                  string
---@field public uuid                   string
---@field public visible                fml.types.collection.IObservable
---@field public get_current            fun(self: fml.types.ui.search.IState): fml.types.ui.search.IItem|nil, integer, string|nil
---@field public get_current_lnum       fun(self: fml.types.ui.search.IState): integer
---@field public locate                 fun(self: fml.types.ui.search.IState, lnum: integer): integer
---@field public mark_dirty             fun(self: fml.types.ui.search.IState): nil
---@field public moveup                 fun(self: fml.types.ui.search.IState): integer
---@field public movedown               fun(self: fml.types.ui.search.IState): integer

---@class fml.types.ui.search.IInput
---@field public state                  fml.types.ui.search.IState
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IInput): integer
---@field public destroy                fun(self: fml.types.ui.search.IInput): nil
---@field public reset_input            fun(self: fml.types.ui.search.IInput, input?: string): nil
---@field public set_virtual_text       fun(self: fml.types.ui.search.IInput): nil

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
---@field public statusline_items       fml.types.ui.search.IStatuslineItem[]
---@field public change_dimension       fun(self: fml.types.ui.search.ISearch, dimension: fml.types.ui.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.types.ui.search.ISearch, title: string): nil
---@field public change_preview_title   fun(self: fml.types.ui.search.ISearch, title: string): nil
---@field public close                  fun(self: fml.types.ui.search.ISearch): nil
---@field public focus                  fun(self: fml.types.ui.search.ISearch): nil
---@field public get_winnr_input        fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public get_winnr_preview      fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public open                   fun(self: fml.types.ui.search.ISearch): nil
---@field public toggle                 fun(self: fml.types.ui.search.ISearch): nil
