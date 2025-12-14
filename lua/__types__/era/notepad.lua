---@class era.t.INotepadItemMeta
---@field public uuid                   string Unique identifier (UUID v4)
---@field public name                   string Human-readable name
---@field public created_at             string ISO 8601 UTC timestamp (managed by source)
---@field public updated_at             string ISO 8601 UTC timestamp (managed by source)

---@class era.t.INotepadItemState : era.t.INotepadItemMeta
---@field public content                string|nil Note content (nil if not loaded)
---@field public original               string|nil Original content for dirty checking (nil if not loaded)

---@class era.t.INotepadItemPatch
---@field public name                   string Human-readable name
---@field public content                string Note content (markdown format)

---@class era.t.INotepadItemData : era.t.INotepadItemMeta
---@field public content                string Note content (markdown format)

---@class era.t.INotepadSourceConfig
---@field public name                   string Unique source identifier
---@field public filepath               string Absolute path to storage file
---@field public default_item_name      fun(): string Default name generator for untitled items

---@class era.t.INotepadSourceData
---@field public items                  table[] Array of note items with {uuid, name, content, created_at, updated_at}
---@field public orders                 string[] Ordered list of UUIDs
---@field public activated_item_uuid    string|nil Currently active note UUID

---@class era.t.INotepadSourceState
---@field public items                  table<string, era.t.INotepadItemState> Map of UUID to note items
---@field public orders                 string[] Ordered list of UUIDs
---@field public active_uuid            string|nil Currently active note UUID
---@field public name_to_uuid           table<string, string> Map of normalized name to UUID for fast lookup
---@field public note_uuid_history      string[] Navigation history stack (most recent at end)
---@field public history_index          integer Current position in history (1-based, 0 means no history)

---@class era.t.INotepadSource
---@field public name                   string Unique source identifier (e.g., "workspace", "global")
---@field public filepath               string Absolute path to storage file
---@field public load                   fun(self: era.t.INotepadSource, force: boolean): era.t.INotepadSourceState Load data from storage
---@field public list                   fun(self: era.t.INotepadSource): era.t.INotepadItemMeta[] Get all note metas in order
---@field public flush                  fun(self: era.t.INotepadSource): boolean Force immediate persistence
---@field public get_activated_uuid     fun(self: era.t.INotepadSource): string|nil Get currently activated note UUID
---@field public set_activated_uuid     fun(self: era.t.INotepadSource, uuid: string|nil): boolean Set activated note UUID (validates existence)
---@field public retrieve               fun(self: era.t.INotepadSource, uuid: string, createIfNonexistent: boolean|nil): era.t.INotepadItemState|nil Retrieve note by UUID, optionally create if not found
---@field public retrieve_by_name       fun(self: era.t.INotepadSource, name: string, createIfNonexistent: boolean|nil): era.t.INotepadItemState|nil Retrieve note by name, optionally create if not found
---@field public create                 fun(self: era.t.INotepadSource, name: string|nil, content: string|nil): era.t.INotepadItemState Create new note (returns existing if name exists)
---@field public update                 fun(self: era.t.INotepadSource, uuid: string, patch: era.t.INotepadItemPatch): boolean Update existing note
---@field public rename                 fun(self: era.t.INotepadSource, uuid: string, new_name: string): boolean Rename note (rejects if name already exists)
---@field public remove                 fun(self: era.t.INotepadSource, uuid: string): boolean Remove note (rejects if last note)
---@field public push_history           fun(self: era.t.INotepadSource, uuid: string): nil Add note to history stack
---@field public can_go_backward        fun(self: era.t.INotepadSource): boolean Check if can navigate backward in history
---@field public can_go_forward         fun(self: era.t.INotepadSource): boolean Check if can navigate forward in history
---@field public go_backward            fun(self: era.t.INotepadSource): string|nil Navigate backward in history, returns UUID
---@field public go_forward             fun(self: era.t.INotepadSource): string|nil Navigate forward in history, returns UUID
---@field public dump_to_json           fun(self: era.t.INotepadSource): era.t.INotepadSourceData Export to standard JSON format
---@field public load_from_json         fun(self: era.t.INotepadSource, json_data: era.t.INotepadSourceData): boolean Import from standard JSON format
---@field public mark_orders_dirty      fun(self: era.t.INotepadSource)|nil Mark orders as dirty for persistence
---@field public mark_active_dirty      fun(self: era.t.INotepadSource)|nil Mark active UUID as dirty for persistence
