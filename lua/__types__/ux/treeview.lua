---@meta

---@alias ux.treeview.NodeId string
---@alias ux.treeview.Revision string
---@alias ux.treeview.NodeRef string|{id: ux.treeview.NodeId}
---@alias ux.treeview.ErrorCode "InvalidUpdate"|"MissingNode"|"Stale"|"Busy"|"Disposed"|"ResourceLimit"
---@alias ux.treeview.Completeness "unknown"|"partial"|"complete"
---@alias ux.treeview.LoadState "idle"|"loading"|"error"
---@alias ux.treeview.Direction "parent"|"last_child_or_sibling"
---@alias ux.treeview.SelectionAction "select_node"|"deselect_node"|"toggle_node"

---@class ux.treeview.IError
---@field public code                   ux.treeview.ErrorCode
---@field public message                string
---@field public node                   ?ux.treeview.NodeId

---@class ux.treeview.IRejected
---@field public kind                   "Rejected"
---@field public error                  ux.treeview.IError

---@class ux.treeview.IRevisions
---@field public commit                 ux.treeview.Revision
---@field public data                   ux.treeview.Revision
---@field public state                  ?ux.treeview.Revision
---@field public selection              ?ux.treeview.Revision

---@class ux.treeview.ISummary
---@field public full                   boolean
---@field public known_roots            integer
---@field public known_self_only        integer
---@field public pending                boolean
---@field public is_empty               boolean

---@class ux.treeview.IDataScope
---@field public kind                   "forest"|"children"|"descendants"
---@field public node                   ?ux.treeview.NodeId

---@alias ux.treeview.IRoot {kind: "children_of", node: ux.treeview.NodeId}|{kind: "forest", nodes: ux.treeview.NodeId[]}

---@class ux.treeview.IDisplay
---@field public mode                   ?"tree"|"list"
---@field public pattern                ?string
---@field public sort                   ?"source"|"name"|"score"
---@field public case_sensitive         ?boolean
---@field public show_hidden            ?boolean
---@field public selected_only          ?boolean
---@field public compress               ?boolean
---@field public branches_first         ?boolean

---@class ux.treeview.INodeData
---@field public label                  string
---@field public can_expand             ?boolean
---@field public foldable               ?boolean
---@field public hidden                 ?boolean
---@field public score                  ?number
---@field public icon                   string|false|nil
---@field public highlight              string|false|nil
---@field public right_text             string|false|nil
---@field public fields                 ?table<string, any>
---@field public completeness           ?ux.treeview.Completeness

---@class ux.treeview.IRecord : ux.treeview.INodeData
---@field public key                    string
---@field public parent                 ?ux.treeview.NodeRef

---Columns, when present, have the same length as keys. Parent indices are 1-based; 0 denotes a scope entry.
---@class ux.treeview.IColumns
---@field public keys                   string[]
---@field public labels                 string[]
---@field public parents                ?integer[]
---@field public parent_keys            ?(string|false)[]
---@field public can_expand             ?boolean[]
---@field public foldable               ?boolean[]
---@field public hidden                 ?boolean[]
---@field public scores                 ?number[]
---@field public icons                  ?(string|false)[]
---@field public highlights             ?(string|false)[]
---@field public right_texts            ?(string|false)[]
---@field public fields                 ?table<string, any>[]
---@field public completeness           ?(ux.treeview.Completeness|false)[]

---@alias ux.treeview.Records ux.treeview.IRecord[]|ux.treeview.IColumns
---@alias ux.treeview.Position "first"|"last"|{before: ux.treeview.NodeRef}|{after: ux.treeview.NodeRef}

---@class ux.treeview.IOperation
---@field public kind                   "insert"|"update"|"reparent"|"reorder"|"remove"
---@field public key                    ?string
---@field public node                   ?ux.treeview.NodeRef
---@field public id                     ?ux.treeview.NodeId
---@field public parent                 ?ux.treeview.NodeRef
---@field public position               ?ux.treeview.Position
---@field public children               ?ux.treeview.NodeRef[]
---@field public label                  ?string
---@field public can_expand             ?boolean
---@field public foldable               ?boolean
---@field public hidden                 ?boolean
---@field public score                  ?number
---@field public icon                   string|false|nil
---@field public highlight              string|false|nil
---@field public right_text             string|false|nil
---@field public fields                 table<string, any>|false|nil
---@field public completeness           ?ux.treeview.Completeness

---@class ux.treeview.IBatch
---@field public base_revision          ux.treeview.Revision
---@field public operations             ux.treeview.IOperation[]

---@class ux.treeview.IImport
---@field public base_revision          ux.treeview.Revision
---@field public scope                  ?ux.treeview.IDataScope
---@field public records                ux.treeview.Records

---@class ux.treeview.IContext
---@field public expected_state         ?ux.treeview.Revision
---@field public frame                  ?yoz.ux.treeview.Frame

---@class ux.treeview.IRange
---@field public frame                  yoz.ux.treeview.Frame
---@field public first                  integer
---@field public last                   integer

---Selection and expansion require recursive to be an actual boolean.
---@class ux.treeview.ICommand
---@field public kind                   ux.treeview.SelectionAction|"set_root"|"set_display"|"set_expanded"|"toggle_expanded"|"set_cursor"|"navigate"|"clear_selection"|"inspect_selection"|"prepare_sources"|"unselect"
---@field public nodes                  ?ux.treeview.NodeId[]
---@field public range                  ?ux.treeview.IRange
---@field public recursive              ?boolean
---@field public value                  ?boolean
---@field public root                   ?ux.treeview.IRoot
---@field public display                ?ux.treeview.IDisplay
---@field public node                   ?ux.treeview.NodeId
---@field public frame                  ?yoz.ux.treeview.Frame
---@field public row                    ?integer
---@field public direction              ?ux.treeview.Direction
---@field public lock                   ?string
---@field public cleanup                ?string
---@field public successful             ?ux.treeview.NodeId[]

---@class ux.treeview.ILimits
---@field public memory_bytes           ?integer
---@field public nodes                  ?integer
---@field public payload_bytes          ?integer
---@field public states                 ?integer
---@field public views                  ?integer
---@field public queued_actions         ?integer
---@field public concurrent_reads       ?integer
---@field public queued_reads           ?integer
---@field public batch_nodes            ?integer
---@field public batch_bytes            ?integer

---@class ux.treeview.IRequest
---@field public work                   string
---@field public token                  yoz.ux.treeview.ReadToken|yoz.ux.treeview.QueryToken
---@field public sequence               ux.treeview.Revision
---@field public source                 yoz.ux.treeview.Source
---@field public node                   ?ux.treeview.NodeId
---@field public pattern                ?string
---@field public options                ?table<string, any>
---@field public is_cancelled           fun(): boolean

---@class ux.treeview.IPage
---@field public records                ux.treeview.Records
---@field public done                   boolean

---@class ux.treeview.IDataOptions
---@field public limits                 ?ux.treeview.ILimits
---@field public read_children          ?fun(request: ux.treeview.IRequest): ux.treeview.IPage|stl.c.Future
---@field public on_effect              ?fun(effect: ux.treeview.IEffect): nil

---@class ux.treeview.IQueryInput
---@field public pattern                string
---@field public options                ?table<string, any>

---@class ux.treeview.IViewOptions
---@field public winnr                  ?integer
---@field public keymaps                ?boolean
---@field public selection_recursive    ?boolean
---@field public glyphs                 ?table<string, string>
---@field public on_activate            ?fun(frame: yoz.ux.treeview.Frame, node: ux.treeview.NodeId): nil
---@field public on_error               ?fun(error: ux.treeview.IError|string): nil

---@class ux.treeview.IEffect
---@field public kind                   "NeedChildren"|"CancelChildren"|"Query"|"CancelQuery"|"TaskFailed"|"RootUnavailable"|"NodeInvalidated"|"ViewChanged"|"SelectionPending"
---@field public node                   ?ux.treeview.NodeId
---@field public nodes                  ?yoz.ux.treeview.NodeIds
---@field public state                  ?string
---@field public lock                   ?string
---@field public work                   ?string
---@field public session                ?string
---@field public sequence               ?ux.treeview.Revision
---@field public token                  ?yoz.ux.treeview.ReadToken|yoz.ux.treeview.QueryToken
---@field public error                  ?ux.treeview.IError

---@class ux.treeview.IReply
---@field public kind                   "Applied"|"NoChange"|"Inspected"|"Ready"|"Pending"|"Locked"|"Rejected"
---@field public error                  ?ux.treeview.IError
---@field public revisions              ?ux.treeview.IRevisions
---@field public effects                ?ux.treeview.IEffect[]
---@field public summary                ?ux.treeview.ISummary
---@field public subtree_roots          ?yoz.ux.treeview.NodeIds
---@field public self_only_nodes        ?yoz.ux.treeview.NodeIds
---@field public needed_children        ?yoz.ux.treeview.NodeIds
---@field public source                 ?yoz.ux.treeview.Source
---@field public cleanup                ?string
---@field public token                  ?string

---@class ux.treeview.IFrameHeader
---@field public frame_id               string
---@field public state_id               string
---@field public data_id                string
---@field public data_revision          ux.treeview.Revision
---@field public state_revision         ux.treeview.Revision
---@field public selection_revision     ux.treeview.Revision
---@field public commit_revision        ux.treeview.Revision
---@field public layout_revision        ux.treeview.Revision
---@field public row_count              integer
---@field public mode                   "tree"|"list"
---@field public root                   {kind: string, node: ux.treeview.NodeId|nil, nodes: yoz.ux.treeview.NodeIds|nil}
---@field public cursor                 ?ux.treeview.NodeId
---@field public cursor_row             ?integer
---@field public summary                ux.treeview.ISummary
---@field public needed_children        yoz.ux.treeview.NodeIds
---@field public queries                table[]
---@field public visited_nodes          integer

---All row columns are dense; absent text/error columns use false. Row indices are 1-based, with 0 for no target.
---@class ux.treeview.IRows
---@field public first                  integer
---@field public ids                    ux.treeview.NodeId[]
---@field public labels                 string[]
---@field public depths                 integer[]
---@field public parents                integer[]
---@field public last_children          integer[]
---@field public last_descendants       integer[]
---@field public connector_last         boolean[]
---@field public marked                 boolean[]
---@field public full                   boolean[]
---@field public pending                boolean[]
---@field public expanded               boolean[]
---@field public can_expand             boolean[]
---@field public icons                  (string|false)[]
---@field public highlights             (string|false)[]
---@field public right_texts            (string|false)[]
---@field public load_states            ux.treeview.LoadState[]
---@field public errors                 (ux.treeview.IError|false)[]
---@field public matches                integer[][][]
---@field public folded_ids             yoz.ux.treeview.NodeIds[]
---@field public guides                 integer[][]

---@class ux.treeview.IRenderContext
---@field public version                ?ux.treeview.Revision
---@field public indent                 ?integer
---@field public slots                  ?integer
---@field public separator              ?string

---@class ux.treeview.INode : ux.treeview.INodeData
---@field public id                     ux.treeview.NodeId
---@field public key                    string
---@field public parent                 ?ux.treeview.NodeId
---@field public child_count            integer
---@field public load_state             ux.treeview.LoadState
---@field public error                  ?ux.treeview.IError
