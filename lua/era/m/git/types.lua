----------------------------------------------------------------------------------------------------
-- Core types
----------------------------------------------------------------------------------------------------

---@alias era.m.git.HunkType yoz.git.HunkType

---@alias era.m.git.SignType
---| "add"
---| "change"
---| "changedelete"
---| "delete"
---| "topdelete"
---| "untracked"

---@alias era.m.git.StageState
---| "mixed"
---| "staged"
---| "unstaged"
---| nil

----------------------------------------------------------------------------------------------------
-- Hunk types
----------------------------------------------------------------------------------------------------

---@class era.m.git.Document : yoz.git.TextDocument
---@field public bomb                   boolean
---@field public encoding               string

---@alias era.m.git.Hunk yoz.git.Hunk
---@alias era.m.git.HunkNode yoz.git.HunkNode

---@class era.m.git.HunkSummary
---@field public added                  integer
---@field public changed                integer
---@field public removed                integer

---@class era.m.git.Sign
---@field public count                  ?integer
---@field public lnum                   integer
---@field public type                   era.m.git.SignType

----------------------------------------------------------------------------------------------------
-- Repository types
----------------------------------------------------------------------------------------------------

---@class era.m.git.Repo
---@field public abbrev_head            string
---@field public add_intent_to_add      fun(self: era.m.git.Repo, file: string, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public apply_patch            fun(self: era.m.git.Repo, patch: string, reverse: boolean|nil, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public commondir              ?string
---@field public detached               boolean
---@field public get_file_info          fun(self: era.m.git.Repo, file: string, token: stl.c.CancellationToken|nil): stl.c.Future Resolves with stl.git.IFileInfoResult
---@field public get_relpath            fun(self: era.m.git.Repo, file: string): string
---@field public get_show_blob          fun(self: era.m.git.Repo, object: string, token: stl.c.CancellationToken|nil): stl.c.Future Resolves with stl.git.IBlobResult
---@field public get_show_text          fun(self: era.m.git.Repo, object: string, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public gitdir                 string
---@field public hash_object            fun(self: era.m.git.Repo, file: string, content: string, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public refresh_head           fun(self: era.m.git.Repo, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public reset_file             fun(self: era.m.git.Repo, file: string, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public stage_file             fun(self: era.m.git.Repo, file: string, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public toplevel               string
---@field public unstage_file           fun(self: era.m.git.Repo, file: string, token: stl.c.CancellationToken|nil): stl.c.Future
---@field public update_index           fun(self: era.m.git.Repo, mode_bits: string, object_name: string, file: string, token: stl.c.CancellationToken|nil, add: boolean|nil): stl.c.Future

---@class era.m.git.FileInfo
---@field public has_conflicts          ?boolean
---@field public mode_bits              ?string
---@field public object_name            ?string
---@field public relpath                ?string

----------------------------------------------------------------------------------------------------
-- Buffer types
----------------------------------------------------------------------------------------------------

---@class era.m.git.buffer.ICache
---@field public attached               boolean
---@field public bufnr                  integer
---@field public changedtick            integer
---@field public document_format        ?string
---@field public dirty                  boolean
---@field public file                   string
---@field public force_next_update      boolean
---@field public hunks                  ?era.m.git.Hunk[]
---@field public hunks_staged           ?era.m.git.Hunk[]
---@field public head_document          ?era.m.git.Document
---@field public index_document         ?era.m.git.Document
---@field public mode_bits              ?string
---@field public object_name            ?string
---@field public relpath                string
---@field public repo                   era.m.git.Repo
---@field public untracked              boolean
---@field public update_throttled      ?stl.timer.IDisposableCallable

----------------------------------------------------------------------------------------------------
-- Blame types
----------------------------------------------------------------------------------------------------

---@alias era.m.git.BlameInfo yoz.git.BlameInfo

----------------------------------------------------------------------------------------------------
-- Status types
----------------------------------------------------------------------------------------------------

---@alias era.m.git.status.ICollectOpts yoz.git.IStatusOptions
---@alias era.m.git.status.INumstat yoz.git.Numstat
---@alias era.m.git.status.ICollectResult yoz.git.StatusData
---@alias era.m.git.StatusEntry yoz.git.StatusEntry

---@alias era.m.git.StatusChangeScope "index"|"unknown"

---@class era.m.git.state.IRefreshEvent
---@field public change_scope           era.m.git.StatusChangeScope
---@field public generation             integer

return {}
