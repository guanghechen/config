---@meta

---@class ux.filetree.IOptions
---@field on_effect                     ?fun(effect: ux.filetree.IEffect): nil

---@class ux.filetree.IObserver
---@field on_effect                     ?fun(effect: ux.filetree.IEffect): nil
---@field on_source_changed             ?fun(revision: yoz.ux.treeview.Revision): nil

---@alias ux.filetree.IEffect yoz.ux.treeview.IEffect|{kind: "WatchStatus", status: yoz.ux.filetree.IWatchStatus}

---Plans that Lua callers build. Their task state is the Lua state, which the wrapper turns into the native state, so a
---plan reaches native code only through the wrapper.
---@class ux.filetree.IOperationPlan
---@field kind                          "copy"|"move"|"delete"|"trash"
---@field source                        yoz.ux.treeview.Source
---@field nodes                         yoz.ux.treeview.NodeIds|string[]
---@field target                        ?yoz.ux.filetree.Resource
---@field name                          ?string
---@field task                          ?{state: ux.treeview.State, lock: string, cleanup: string}
---@field prepare_move                  ?boolean Request editor preparation after conflict confirmation and before move IO.
