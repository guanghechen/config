----------------------------------------------------------------------------------------------------
-- Core types
----------------------------------------------------------------------------------------------------

---@alias era.m.git.HunkType
---| "add"
---| "change"
---| "delete"

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

---@class era.m.git.Document
---@field public bomb                   boolean
---@field public encoding               string
---@field public eol                    string
---@field public lines                  string[]
---@field public text                   string

---@class era.m.git.Hunk
---@field public added                  era.m.git.HunkNode
---@field public head                   string
---@field public removed                era.m.git.HunkNode
---@field public type                   era.m.git.HunkType
---@field public vend                   integer

---@class era.m.git.HunkNode
---@field public count                  integer
---@field public lines                  string[]
---@field public no_nl_at_eof           ?boolean
---@field public start                  integer

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

---@class era.m.git.BlameInfo
---@field public abbrev_sha             string
---@field public author                 string
---@field public author_mail            string
---@field public author_time            integer
---@field public author_tz              string
---@field public committer              string
---@field public committer_mail         string
---@field public committer_time         integer
---@field public committer_tz           string
---@field public filename               string
---@field public final_lnum             integer
---@field public num_lines              integer
---@field public orig_lnum              integer
---@field public previous               ?string
---@field public previous_filename      ?string
---@field public sha                    string
---@field public summary                string

----------------------------------------------------------------------------------------------------
-- Status types
----------------------------------------------------------------------------------------------------

---@class era.m.git.status.ICollectOpts
---@field public base                   ?string
---@field public include_numstat        ?boolean
---@field public include_untracked      ?boolean

---@class era.m.git.status.INumstat
---@field public insertions             integer
---@field public deletions              integer

---@class era.m.git.status.ICollectResult
---@field public status_map             table<string, era.m.git.StatusEntry>
---@field public status_groups          table<string, table<string, boolean>>
---@field public numstats               { staged: table<string, era.m.git.status.INumstat>, unstaged: table<string, era.m.git.status.INumstat> }|nil

---@alias era.m.git.StatusChangeScope "index"|"unknown"

---@class era.m.git.state.IRefreshEvent
---@field public change_scope           era.m.git.StatusChangeScope
---@field public generation             integer

---@class era.m.git.StatusEntry
---@field public categories             table<string, boolean>
---@field public codes                  table<string, boolean>
---@field public display                string
---@field public path                   string
---@field public relative               string
---@field public stage                  era.m.git.StageState
---@field public staged                 table<string, boolean>
---@field public staged_bits            integer
---@field public staged_display         string
---@field public staged_new_object_name string|nil
---@field public staged_old_object_name string|nil
---@field public staged_prev_relative   string|nil
---@field public summary                ?string
---@field public unstaged               table<string, boolean>
---@field public unstaged_bits          integer
---@field public unstaged_display       string
---@field public unstaged_new_object_name string|nil
---@field public unstaged_old_object_name string|nil
---@field public unstaged_prev_relative string|nil

----------------------------------------------------------------------------------------------------
-- Aggregated cache types
----------------------------------------------------------------------------------------------------

---@class era.m.git.status.IAggregatedCache
---@field public dir_cache              table<string, era.m.git.status.IDirInfo|false>
---@field public file_display           table<string, string>
---@field public file_stage             table<string, era.m.git.StageState>
---@field public file_summary           table<string, string|nil>
---@field public staged_files           string[]
---@field public status_table           table<string, era.m.git.StatusEntry>
---@field public unstaged_files         string[]

---@class era.m.git.status.IDirInfo
---@field public codes                  table<string, boolean>
---@field public display                string
---@field public stage                  era.m.git.StageState
---@field public summary                ?string

----------------------------------------------------------------------------------------------------

return {}
