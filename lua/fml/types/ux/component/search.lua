---@class t.fml.ux.search.ISearch : t.eve.ux.IWidget
---@field public state                  t.fml.ux.search.IState
---@field public change_dimension       fun(self: t.fml.ux.search.ISearch, dimension: t.fml.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: t.fml.ux.search.ISearch, title: string): nil
---@field public change_preview_title   fun(self: t.fml.ux.search.ISearch, title: string): nil
---@field public close                  fun(self: t.fml.ux.search.ISearch): nil
---@field public focus                  fun(self: t.fml.ux.search.ISearch): nil
---@field public get_winnr_input        fun(self: t.fml.ux.search.ISearch): integer|nil
---@field public get_winnr_main         fun(self: t.fml.ux.search.ISearch): integer|nil
---@field public get_winnr_preview      fun(self: t.fml.ux.search.ISearch): integer|nil
---@field public open                   fun(self: t.fml.ux.search.ISearch): nil
---@field public reset_input            fun(self: t.fml.ux.search.ISearch, text: string): nil
---@field public toggle                 fun(self: t.fml.ux.search.ISearch): nil

---@alias t.fml.ux.search.IOnClose
---| fun(): nil

---@alias t.fml.ux.search.IOnConfirm
---| fun(item: t.fml.ux.search.IItem): t.eve.e.WidgetConfirmAction|nil

---@alias t.fml.ux.search.IOnInvisible
---| fun(): nil

---@alias t.fml.ux.search.IOnMainRendered
---| fun(): nil

---@alias t.fml.ux.search.IOnPreviewRendered
---| fun(): nil

---@alias t.fml.ux.search.IOnResume
---| fun(): nil

---@alias t.fml.ux.search.IFetchPreviewData
---| fun(item: t.fml.ux.search.IItem): t.fml.ux.search.preview.IData|nil

---@alias t.fml.ux.search.IPatchPreviewData
---| fun(item: t.fml.ux.search.IItem, last_item: t.fml.ux.search.IItem, last_data: t.fml.ux.search.preview.IData): t.fml.ux.search.preview.IData

---@alias t.fml.ux.search.IFetchDataCallback
---| fun(ok: true, data: t.fml.ux.search.IData|nil): nil
---| fun(ok: false, error: string|nil): nil

---@alias t.fml.ux.search.IFetchData
---| fun(input: string, force: boolean, callback: t.fml.ux.search.IFetchDataCallback): nil

---@class t.fml.ux.search.IData
---@field public items                  t.fml.ux.search.IItem[]
---@field public present_uuid           ?string
---@field public cursor_uuid            ?string

---@class t.fml.ux.search.IItem
---@field public group                  string|nil
---@field public parent                 string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             t.eve.IHighlightInline[]

---@class t.fml.ux.search.preview.IData
---@field public lines                  string[]
---@field public highlights             t.eve.IHighlight[]
---@field public filetype               string|nil
---@field public title                  string
---@field public lnum                   integer|nil
---@field public col                    integer|nil

---@class t.fml.ux.search.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class t.fml.ux.search.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public width                  ?number
---@field public width_preview          ?number

---@class t.fml.ux.search.preview.IWinOpts
---@field public title                  string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class t.fml.ux.search.IState
---@field public dirtier_dimension      t.eve.collection.IDirtier
---@field public dirtier_data           t.eve.collection.IDirtier
---@field public dirtier_data_cache     t.eve.collection.IDirtier
---@field public dirtier_main           t.eve.collection.IDirtier
---@field public dirtier_preview        t.eve.collection.IDirtier
---@field public enable_multiline_input boolean
---@field public input                  t.eve.collection.IObservable
---@field public input_history          t.eve.collection.IHistory|nil
---@field public input_line_count       t.eve.collection.IObservable
---@field public item_present_uuid      string|nil
---@field public items                  t.fml.ux.search.IItem[]
---@field public max_width              integer
---@field public status                 t.eve.collection.IObservable
---@field public title                  string
---@field public uuid                   string
---@field public get_current            fun(self: t.fml.ux.search.IState): t.fml.ux.search.IItem|nil, integer, string|nil
---@field public get_current_lnum       fun(self: t.fml.ux.search.IState): integer
---@field public get_current_uuid       fun(self: t.fml.ux.search.IState): string|nil
---@field public has_item_deleted       fun(self: t.fml.ux.search.IState, uuid: string): boolean
---@field public locate                 fun(self: t.fml.ux.search.IState, lnum: integer): integer
---@field public mark_item_deleted      fun(self: t.fml.ux.search.IState, uuid: string): nil
---@field public mark_all_items_deleted fun(self: t.fml.ux.search.IState): nil
---@field public moveup                 fun(self: t.fml.ux.search.IState): integer
---@field public movedown               fun(self: t.fml.ux.search.IState): integer
---@field public show_state             fun(self: t.fml.ux.search.IState): nil

---@class t.fml.ux.search.IInput
---@field public state                  t.fml.ux.search.IState
---@field public create_buf_as_needed   fun(self: t.fml.ux.search.IInput): integer, boolean
---@field public destroy                fun(self: t.fml.ux.search.IInput): nil
---@field public reset_input            fun(self: t.fml.ux.search.IInput, input?: string): nil
---@field public set_virtual_text       fun(self: t.fml.ux.search.IInput): nil

---@class t.fml.ux.search.IMain
---@field public state                  t.fml.ux.search.IState
---@field public create_buf_as_needed   fun(self: t.fml.ux.search.IMain): integer
---@field public destroy                fun(self: t.fml.ux.search.IMain): nil
---@field public place_lnum_sign        fun(self: t.fml.ux.search.IMain): integer|nil
---@field public render                 fun(self: t.fml.ux.search.IMain): nil

---@class t.fml.ux.search.IPreview
---@field public state                  t.fml.ux.search.IState
---@field public create_buf_as_needed   fun(self: t.fml.ux.search.IPreview): integer, boolean
---@field public destroy                fun(self: t.fml.ux.search.IPreview): nil
---@field public get_current_location   fun(self: t.fml.ux.search.IPreview): integer|nil, integer|nil
---@field public render                 fun(self: t.fml.ux.search.IPreview): nil
