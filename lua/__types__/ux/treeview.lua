---@meta

---@class ux.treeview.IRejected
---@field public kind                   "Rejected"
---@field public error                  yoz.ux.treeview.IError

---@class ux.treeview.IRequest
---@field public work                   string
---@field public token                  yoz.ux.treeview.ReadToken|yoz.ux.treeview.QueryToken
---@field public sequence               yoz.ux.treeview.Revision
---@field public source                 yoz.ux.treeview.Source
---@field public node                   ?yoz.ux.treeview.NodeId
---@field public pattern                ?string
---@field public options                ?table<string, any>
---@field public is_cancelled           fun(): boolean

---@class ux.treeview.IPage
---@field public records                yoz.ux.treeview.Records
---@field public done                   boolean

---@class ux.treeview.IDataOptions
---@field public limits                 ?yoz.ux.treeview.ILimits
---@field public read_children          ?fun(request: ux.treeview.IRequest): ux.treeview.IPage|stl.c.Future
---@field public on_effect              ?fun(effect: yoz.ux.treeview.IEffect): nil
---The preparing argument excludes waiting for a source publication deadline.
---@field public after_poll             ?fun(preparing: boolean): boolean|nil Runs after effects, views and reads; true requests another tick, false waits for notifications, nil suspends the owner.

---@class ux.treeview.IViewOptions
---@field public winnr                  ?integer
---@field public bufnr                  ?integer Empty scratch buffer whose ownership transfers to the view.
---@field public bufname                ?string
---@field public keymaps                ?boolean
---@field public selection_recursive    ?boolean
---@field public on_attach              ?fun(view: ux.treeview.View): nil Called after each window binding, before its first frame request; failure detaches the view.
---@field public prepare_frame          ?fun(view: ux.treeview.View, frame: yoz.ux.treeview.Frame, first: integer, last: integer, rows: yoz.ux.treeview.IRows): stl.c.Future Resolves to a commit callback or false to retry; callback may return true if decorations are unchanged. Viewport is 0-based, half-open; rows are shared readonly input.
---@field public decorate_row           ?fun(view: ux.treeview.View, frame: yoz.ux.treeview.Frame, row: integer, node: yoz.ux.treeview.NodeId, col: integer, label: string, expanded: boolean): table[]|nil Bounded redraw callback; ephemeral decorations only. Returned virt_text chunks go into the row's right-aligned mark before its right text and selection mark. Expansion comes from the published viewport rows.
---@field public reserve_selection      ?boolean Keep the selection mark column while nothing is selected, so right-aligned columns line up with another view.
---@field public on_frame               ?fun(frame: yoz.ux.treeview.Frame): nil
---@field public glyphs                 ?table<string, string>
---@field public on_activate            ?fun(frame: yoz.ux.treeview.Frame, node: yoz.ux.treeview.NodeId): nil
---@field public on_error               ?fun(error: yoz.ux.treeview.IError|string): nil
