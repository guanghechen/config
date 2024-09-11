---@alias fml.types.ui.search.IOnClose
---| fun(): nil

---@alias fml.types.ui.search.IOnConfirm
---| fun(item: fml.types.ui.search.IItem): eve.enums.WidgetConfirmAction|nil

---@alias fml.types.ui.search.IOnInvisible
---| fun(): nil

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
---| fun(input: string, force: boolean, callback: fml.types.ui.search.IFetchDataCallback): nil

---@class fml.types.ui.search.IData
---@field public items                  fml.types.ui.search.IItem[]
---@field public present_uuid           ?string
---@field public cursor_uuid            ?string

---@class fml.types.ui.search.IItem
---@field public group                  string|nil
---@field public parent                 string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             eve.types.ux.IInlineHighlight[]

---@class fml.ui.search.preview.IData
---@field public lines                  string[]
---@field public highlights             eve.types.ux.IHighlight[]
---@field public filetype               string|nil
---@field public title                  string
---@field public lnum                   integer|nil
---@field public col                    integer|nil

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
---@field public dirtier_dimension      eve.types.collection.IDirtier
---@field public dirtier_data           eve.types.collection.IDirtier
---@field public dirtier_data_cache     eve.types.collection.IDirtier
---@field public dirtier_main           eve.types.collection.IDirtier
---@field public dirtier_preview        eve.types.collection.IDirtier
---@field public enable_multiline_input boolean
---@field public input                  eve.types.collection.IObservable
---@field public input_history          eve.types.collection.IHistory|nil
---@field public input_line_count       eve.types.collection.IObservable
---@field public item_present_uuid      string|nil
---@field public items                  fml.types.ui.search.IItem[]
---@field public max_width              integer
---@field public status                 eve.types.collection.IObservable
---@field public title                  string
---@field public uuid                   string
---@field public get_current            fun(self: fml.types.ui.search.IState): fml.types.ui.search.IItem|nil, integer, string|nil
---@field public get_current_lnum       fun(self: fml.types.ui.search.IState): integer
---@field public get_current_uuid       fun(self: fml.types.ui.search.IState): string|nil
---@field public has_item_deleted       fun(self: fml.types.ui.search.IState, uuid: string): boolean
---@field public locate                 fun(self: fml.types.ui.search.IState, lnum: integer): integer
---@field public mark_item_deleted      fun(self: fml.types.ui.search.IState, uuid: string): nil
---@field public mark_all_items_deleted fun(self: fml.types.ui.search.IState): nil
---@field public moveup                 fun(self: fml.types.ui.search.IState): integer
---@field public movedown               fun(self: fml.types.ui.search.IState): integer
---@field public show_state             fun(self: fml.types.ui.search.IState): nil

---@class fml.types.ui.search.IInput
---@field public state                  fml.types.ui.search.IState
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IInput): integer, boolean
---@field public destroy                fun(self: fml.types.ui.search.IInput): nil
---@field public reset_input            fun(self: fml.types.ui.search.IInput, input?: string): nil
---@field public set_virtual_text       fun(self: fml.types.ui.search.IInput): nil

---@class fml.types.ui.search.IMain
---@field public state                  fml.types.ui.search.IState
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IMain): integer
---@field public destroy                fun(self: fml.types.ui.search.IMain): nil
---@field public place_lnum_sign        fun(self: fml.types.ui.search.IMain): integer|nil
---@field public render                 fun(self: fml.types.ui.search.IMain): nil

---@class fml.types.ui.search.IPreview
---@field public state                  fml.types.ui.search.IState
---@field public create_buf_as_needed   fun(self: fml.types.ui.search.IPreview): integer, boolean
---@field public destroy                fun(self: fml.types.ui.search.IPreview): nil
---@field public get_current_location   fun(self: fml.types.ui.search.IPreview): integer|nil, integer|nil
---@field public render                 fun(self: fml.types.ui.search.IPreview): nil

---@class fml.types.ui.search.ISearch : eve.types.ux.IWidget
---@field public state                  fml.types.ui.search.IState
---@field public change_dimension       fun(self: fml.types.ui.search.ISearch, dimension: fml.types.ui.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.types.ui.search.ISearch, title: string): nil
---@field public change_preview_title   fun(self: fml.types.ui.search.ISearch, title: string): nil
---@field public close                  fun(self: fml.types.ui.search.ISearch): nil
---@field public focus                  fun(self: fml.types.ui.search.ISearch): nil
---@field public get_winnr_input        fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public get_winnr_main         fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public get_winnr_preview      fun(self: fml.types.ui.search.ISearch): integer|nil
---@field public open                   fun(self: fml.types.ui.search.ISearch): nil
---@field public reset_input            fun(self: fml.types.ui.search.ISearch, text: string): nil
---@field public toggle                 fun(self: fml.types.ui.search.ISearch): nil
