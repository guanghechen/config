---@class fml.t.ux.search.ISearch : eve.t.ux.IWidget
---@field public state                  fml.t.ux.search.IState
---@field public change_dimension       fun(self: fml.t.ux.search.ISearch, dimension: fml.t.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.t.ux.search.ISearch, title: string): nil
---@field public change_preview_title   fun(self: fml.t.ux.search.ISearch, title: string): nil
---@field public focus                  fun(self: fml.t.ux.search.ISearch): nil
---@field public get_winnr_input        fun(self: fml.t.ux.search.ISearch): integer|nil
---@field public get_winnr_main         fun(self: fml.t.ux.search.ISearch): integer|nil
---@field public get_winnr_preview      fun(self: fml.t.ux.search.ISearch): integer|nil
---@field public open                   fun(self: fml.t.ux.search.ISearch): nil
---@field public reset_input            fun(self: fml.t.ux.search.ISearch, text: string): nil
---@field public toggle                 fun(self: fml.t.ux.search.ISearch): nil

---@alias fml.t.ux.search.IOnClose
---| fun(): nil

---@alias fml.t.ux.search.IOnConfirm
---| fun(item: fml.t.ux.search.IItem): eve.e.WidgetConfirmAction|nil

---@alias fml.t.ux.search.IOnInvisible
---| fun(): nil

---@alias fml.t.ux.search.IOnMainRendered
---| fun(): nil

---@alias fml.t.ux.search.IOnPreviewRendered
---| fun(): nil

---@alias fml.t.ux.search.IOnResume
---| fun(): nil

---@alias fml.t.ux.search.IFetchPreviewData
---| fun(item: fml.t.ux.search.IItem): fml.t.ux.search.preview.IData|nil

---@alias fml.t.ux.search.IPatchPreviewData
---| fun(item: fml.t.ux.search.IItem, last_item: fml.t.ux.search.IItem, last_data: fml.t.ux.search.preview.IData): fml.t.ux.search.preview.IData

---@alias fml.t.ux.search.IFetchDataCallback
---| fun(ok: true, data: fml.t.ux.search.IData|nil): nil
---| fun(ok: false, error: string|nil): nil

---@alias fml.t.ux.search.IFetchData
---| fun(input: string, force: boolean, callback: fml.t.ux.search.IFetchDataCallback): nil

---@class fml.t.ux.search.IData
---@field public items                  fml.t.ux.search.IItem[]
---@field public present_uuid           ?string
---@field public cursor_uuid            ?string

---@class fml.t.ux.search.IItem
---@field public group                  string|nil
---@field public parent                 string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             eve.t.IHighlightInline[]

---@class fml.t.ux.search.preview.IData
---@field public lines                  string[]
---@field public highlights             eve.t.IHighlight[]
---@field public filetype               string|nil
---@field public title                  string
---@field public lnum                   integer|nil
---@field public col                    integer|nil

---@class fml.t.ux.search.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class fml.t.ux.search.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class fml.t.ux.search.preview.IWinOpts
---@field public title                  string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.t.ux.search.IState
---@field public dirtier_dimension      eve.lib.collection.IDirtier
---@field public dirtier_data           eve.lib.collection.IDirtier
---@field public dirtier_data_cache     eve.lib.collection.IDirtier
---@field public dirtier_main           eve.lib.collection.IDirtier
---@field public dirtier_preview        eve.lib.collection.IDirtier
---@field public state_has_matched      eve.lib.collection.IObservable
---@field public enable_multiline_input boolean
---@field public input                  eve.lib.collection.IObservable
---@field public input_history          eve.lib.collection.IHistory|nil
---@field public input_line_count       eve.lib.collection.IObservable
---@field public item_present_uuid      string|nil
---@field public items                  fml.t.ux.search.IItem[]
---@field public max_width              integer
---@field public status                 eve.lib.collection.IObservable
---@field public title                  string
---@field public uuid                   string
---@field public get_current            fun(self: fml.t.ux.search.IState): fml.t.ux.search.IItem|nil, integer, string|nil
---@field public get_current_lnum       fun(self: fml.t.ux.search.IState): integer
---@field public get_current_uuid       fun(self: fml.t.ux.search.IState): string|nil
---@field public has_item_deleted       fun(self: fml.t.ux.search.IState, uuid: string): boolean
---@field public locate                 fun(self: fml.t.ux.search.IState, lnum: integer): integer
---@field public mark_item_deleted      fun(self: fml.t.ux.search.IState, uuid: string): nil
---@field public mark_all_items_deleted fun(self: fml.t.ux.search.IState): nil
---@field public moveup                 fun(self: fml.t.ux.search.IState): integer
---@field public movedown               fun(self: fml.t.ux.search.IState): integer
---@field public show_state             fun(self: fml.t.ux.search.IState): nil

---@class fml.t.ux.search.IInput
---@field public state                  fml.t.ux.search.IState
---@field public create_buf_as_needed   fun(self: fml.t.ux.search.IInput): integer
---@field public destroy                fun(self: fml.t.ux.search.IInput): nil
---@field public reset_input            fun(self: fml.t.ux.search.IInput, input?: string): nil
---@field public set_virtual_text       fun(self: fml.t.ux.search.IInput): nil

---@class fml.t.ux.search.IMain
---@field public state                  fml.t.ux.search.IState
---@field public create_buf_as_needed   fun(self: fml.t.ux.search.IMain): integer
---@field public destroy                fun(self: fml.t.ux.search.IMain): nil
---@field public place_lnum_sign        fun(self: fml.t.ux.search.IMain): integer|nil
---@field public render                 fun(self: fml.t.ux.search.IMain): nil

---@class fml.t.ux.search.IPreview
---@field public state                  fml.t.ux.search.IState
---@field public create_buf_as_needed   fun(self: fml.t.ux.search.IPreview): integer
---@field public destroy                fun(self: fml.t.ux.search.IPreview): nil
---@field public get_current_location   fun(self: fml.t.ux.search.IPreview): integer|nil, integer|nil
---@field public render                 fun(self: fml.t.ux.search.IPreview): nil
