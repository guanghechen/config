---@meta

---@alias yoz.ux.treeview.NodeId string
---@alias yoz.ux.treeview.Revision string
---@alias yoz.ux.treeview.NodeRef string|{id: yoz.ux.treeview.NodeId}
---@alias yoz.ux.treeview.ErrorCode "ProviderError"|"NotFound"|"InvalidUpdate"|"MissingNode"|"Stale"|"Busy"|"Disposed"|"ResourceLimit"
---@alias yoz.ux.treeview.Completeness "unknown"|"partial"|"complete"
---@alias yoz.ux.treeview.LoadState "idle"|"loading"|"error"
---@alias yoz.ux.treeview.Direction "parent"|"last_child_or_sibling"
---@alias yoz.ux.treeview.SelectionAction "select_node"|"deselect_node"|"toggle_node"

---@class yoz.ux.treeview.IError
---@field public code                   yoz.ux.treeview.ErrorCode
---@field public message                string
---@field public node                   ?yoz.ux.treeview.NodeId

---@class yoz.ux.treeview.IRevisions
---@field public commit                 yoz.ux.treeview.Revision
---@field public data                   yoz.ux.treeview.Revision
---@field public state                  ?yoz.ux.treeview.Revision
---@field public selection              ?yoz.ux.treeview.Revision

---@class yoz.ux.treeview.ISummary
---@field public full                   boolean
---@field public known_roots            integer
---@field public known_self_only        integer
---@field public pending                boolean
---@field public is_empty               boolean

---@class yoz.ux.treeview.IDataScope
---@field public kind                   "forest"|"children"|"descendants"
---@field public node                   ?yoz.ux.treeview.NodeId

---@alias yoz.ux.treeview.IRoot {kind: "children_of", node: yoz.ux.treeview.NodeId}|{kind: "forest", nodes: yoz.ux.treeview.NodeId[]}

---@class yoz.ux.treeview.IDisplay
---@field public mode                   ?"tree"|"list"
---@field public pattern                ?string
---@field public filter                 ?yoz.ux.treeview.NodeId[]|yoz.ux.treeview.NodeIds Ordered result membership. Tree retains connecting ancestors.
---@field public sort                   ?"source"|"name"|"score"
---@field public list_text              ?"label"|"ancestry"
---@field public list_depth             ?integer Maximum depth below display roots; zero lists direct children only.
---@field public list_from_depth        ?integer Tree groups above this depth retain expansion; lower scopes are flat Lists. Requires compress=false.
---@field public context_label          ?string Leading ChildrenOf root row in List mode; keeps the root identity.
---@field public branch_suffix          ?string Display/match suffix for expandable List labels; at most 32 bytes.
---@field public case_sensitive         ?boolean
---@field public fuzzy                  ?boolean
---@field public regex                  ?boolean Takes precedence over fuzzy.
---@field public show_hidden            ?boolean
---@field public selected_only          ?boolean
---@field public compress               ?boolean
---@field public branches_first         ?boolean

---@class yoz.ux.treeview.INodeData
---@field public label                  string
---@field public can_expand             ?boolean
---@field public foldable               ?boolean
---@field public hidden                 ?boolean
---@field public score                  ?number
---@field public icon                   string|false|nil
---@field public highlight              string|false|nil
---@field public right_text             string|false|nil
---@field public fields                 ?table<string, any>
---@field public completeness           ?yoz.ux.treeview.Completeness

---@class yoz.ux.treeview.IRecord : yoz.ux.treeview.INodeData
---@field public key                    string
---@field public parent                 ?yoz.ux.treeview.NodeRef

---Columns, when present, have the same length as keys. Parent indices are 1-based; 0 denotes a scope entry.
---@class yoz.ux.treeview.IColumns
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
---@field public completeness           ?(yoz.ux.treeview.Completeness|false)[]

---@alias yoz.ux.treeview.Records yoz.ux.treeview.IRecord[]|yoz.ux.treeview.IColumns
---@alias yoz.ux.treeview.Position "first"|"last"|{before: yoz.ux.treeview.NodeRef}|{after: yoz.ux.treeview.NodeRef}

---@class yoz.ux.treeview.IOperation
---@field public kind                   "insert"|"update"|"reparent"|"reorder"|"remove"
---@field public key                    ?string
---@field public node                   ?yoz.ux.treeview.NodeRef
---@field public id                     ?yoz.ux.treeview.NodeId
---@field public parent                 ?yoz.ux.treeview.NodeRef
---@field public position               ?yoz.ux.treeview.Position
---@field public children               ?yoz.ux.treeview.NodeRef[]
---@field public label                  ?string
---@field public can_expand             ?boolean
---@field public foldable               ?boolean
---@field public hidden                 ?boolean
---@field public score                  ?number
---@field public icon                   string|false|nil
---@field public highlight              string|false|nil
---@field public right_text             string|false|nil
---@field public fields                 table<string, any>|false|nil
---@field public completeness           ?yoz.ux.treeview.Completeness

---@class yoz.ux.treeview.IBatch
---@field public base_revision          yoz.ux.treeview.Revision
---@field public operations             yoz.ux.treeview.IOperation[]

---@class yoz.ux.treeview.IImport
---@field public base_revision          yoz.ux.treeview.Revision
---@field public scope                  ?yoz.ux.treeview.IDataScope
---@field public records                yoz.ux.treeview.Records

---@class yoz.ux.treeview.IContext
---@field public expected_state         ?yoz.ux.treeview.Revision
---@field public frame                  ?yoz.ux.treeview.Frame

---@class yoz.ux.treeview.IRange
---@field public frame                  yoz.ux.treeview.Frame
---@field public first                  integer
---@field public last                   integer

---Selection and expansion require recursive to be an actual boolean.
---@class yoz.ux.treeview.ICommand
---@field public kind                   yoz.ux.treeview.SelectionAction|"set_root"|"set_display"|"set_expanded"|"toggle_expanded"|"set_cursor"|"navigate"|"clear_selection"|"inspect_selection"|"prepare_sources"|"unselect"
---@field public nodes                  ?yoz.ux.treeview.NodeId[]
---@field public range                  ?yoz.ux.treeview.IRange
---@field public recursive              ?boolean
---@field public value                  ?boolean
---@field public root                   ?yoz.ux.treeview.IRoot
---@field public display                ?yoz.ux.treeview.IDisplay
---@field public node                   ?yoz.ux.treeview.NodeId
---@field public frame                  ?yoz.ux.treeview.Frame
---@field public row                    ?integer
---@field public direction              ?yoz.ux.treeview.Direction
---@field public lock                   ?string
---@field public retry                  ?boolean Retry failed ordinary children slots during source preparation.
---@field public cleanup                ?string
---@field public successful             ?yoz.ux.treeview.NodeId[]

---@class yoz.ux.treeview.ILimits
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

---@class yoz.ux.treeview.IQueryInput
---@field public pattern                string
---@field public options                ?table<string, any>

---@class yoz.ux.treeview.IEffect
---@field public kind                   "NeedChildren"|"CancelChildren"|"Query"|"CancelQuery"|"TaskFailed"|"RootUnavailable"|"NodeInvalidated"|"ViewChanged"|"SelectionPending"
---@field public node                   ?yoz.ux.treeview.NodeId
---@field public nodes                  ?yoz.ux.treeview.NodeIds
---@field public state                  ?string
---@field public lock                   ?string
---@field public work                   ?string
---@field public session                ?string
---@field public sequence               ?yoz.ux.treeview.Revision
---@field public token                  ?yoz.ux.treeview.ReadToken|yoz.ux.treeview.QueryToken
---@field public error                  ?yoz.ux.treeview.IError

---@class yoz.ux.treeview.IReply
---@field public kind                   "Applied"|"NoChange"|"Inspected"|"Ready"|"Pending"|"Locked"|"Rejected"
---@field public error                  ?yoz.ux.treeview.IError
---@field public revisions              ?yoz.ux.treeview.IRevisions
---@field public effects                ?yoz.ux.treeview.IEffect[]
---@field public summary                ?yoz.ux.treeview.ISummary
---@field public subtree_roots          ?yoz.ux.treeview.NodeIds
---@field public self_only_nodes        ?yoz.ux.treeview.NodeIds
---@field public needed_children        ?yoz.ux.treeview.NodeIds
---@field public source                 ?yoz.ux.treeview.Source
---@field public cleanup                ?string
---@field public token                  ?string

---@class yoz.ux.treeview.IReadyReply : yoz.ux.treeview.IReply
---@field public kind                   "Ready"
---@field public summary                yoz.ux.treeview.ISummary
---@field public subtree_roots          yoz.ux.treeview.NodeIds
---@field public source                 yoz.ux.treeview.Source
---@field public cleanup                string

---@class yoz.ux.treeview.IFrameHeader
---@field public frame_id               string
---@field public state_id               string
---@field public data_id                string
---@field public data_revision          yoz.ux.treeview.Revision
---@field public state_revision         yoz.ux.treeview.Revision
---@field public selection_revision     yoz.ux.treeview.Revision
---@field public selection_purpose      ?string
---@field public commit_revision        yoz.ux.treeview.Revision
---@field public layout_revision        yoz.ux.treeview.Revision
---@field public row_count              integer
---@field public mode                   "tree"|"list"
---@field public root                   {kind: string, node: yoz.ux.treeview.NodeId|nil, nodes: yoz.ux.treeview.NodeIds|nil}
---@field public cursor                 ?yoz.ux.treeview.NodeId
---@field public cursor_row             ?integer
---@field public summary                yoz.ux.treeview.ISummary
---@field public needed_children        yoz.ux.treeview.NodeIds
---@field public queries                table[]
---@field public visited_nodes          integer

---@class yoz.ux.treeview.IStateStatus
---@field public revisions              yoz.ux.treeview.IRevisions
---@field public locked                 boolean
---@field public selection_purpose      ?string
---@field public projection_error       ?yoz.ux.treeview.IError

---All row columns are dense; absent text/error columns use false. Row indices are 1-based, with 0 for no target.
---@class yoz.ux.treeview.IRows
---@field public first                  integer
---@field public ids                    yoz.ux.treeview.NodeId[]
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
---@field public load_states            yoz.ux.treeview.LoadState[]
---@field public errors                 (yoz.ux.treeview.IError|false)[]
---@field public matches                integer[][][]
---@field public folded_ids             yoz.ux.treeview.NodeIds[]
---@field public guides                 integer[][]

---@class yoz.ux.treeview.IRenderContext
---@field public version                ?yoz.ux.treeview.Revision
---@field public indent                 ?integer
---@field public slots                  ?integer
---@field public separator              ?string

---The last row is a path node; preceding rows carry only its vertical connection.
---@class yoz.ux.treeview.IGuideSegment
---@field public first                  integer 1-based inclusive, clipped to the viewport.
---@field public last                   integer 1-based inclusive connector row.
---@field public depth                  integer 0-based guide depth.

---@class yoz.ux.treeview.INode : yoz.ux.treeview.INodeData
---@field public id                     yoz.ux.treeview.NodeId
---@field public key                    string
---@field public parent                 ?yoz.ux.treeview.NodeId
---@field public child_count            integer
---@field public load_state             yoz.ux.treeview.LoadState
---@field public error                  ?yoz.ux.treeview.IError
