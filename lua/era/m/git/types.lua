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

---@class era.m.git.Hunk
---@field public added                  era.m.git.HunkNode
---@field public head                   string
---@field public removed                era.m.git.HunkNode
---@field public type                   era.m.git.HunkType
---@field public vend                   integer

---@class era.m.git.HunkNode
---@field public count                  integer
---@field public lines                  string[]
---@field public no_nl_at_eof           boolean|nil
---@field public start                  integer

---@class era.m.git.HunkSummary
---@field public added                  integer
---@field public changed                integer
---@field public removed                integer

---@class era.m.git.Sign
---@field public count                  integer|nil
---@field public lnum                   integer
---@field public type                   era.m.git.SignType

----------------------------------------------------------------------------------------------------
-- Repository types
----------------------------------------------------------------------------------------------------

---@class era.m.git.Repo
---@field public abbrev_head            string
---@field public add_intent_to_add      fun(self: era.m.git.Repo, file: string, callback: fun(ok: boolean))
---@field public apply_patch            fun(self: era.m.git.Repo, patch: string, reverse: boolean|nil, callback: fun(ok: boolean, err: string|nil))
---@field public detached               boolean
---@field public get_file_info          fun(self: era.m.git.Repo, file: string, callback: fun(info: era.m.git.FileInfo|nil))
---@field public get_relpath            fun(self: era.m.git.Repo, file: string): string
---@field public get_show_text          fun(self: era.m.git.Repo, object: string, callback: fun(lines: string[]|nil))
---@field public gitdir                 string
---@field public hash_object            fun(self: era.m.git.Repo, file: string, lines: string[], callback: fun(hash: string|nil))
---@field public refresh_head           fun(self: era.m.git.Repo, callback: (fun(): nil)|nil)
---@field public reset_file             fun(self: era.m.git.Repo, file: string, callback: fun(ok: boolean))
---@field public stage_file             fun(self: era.m.git.Repo, file: string, callback: fun(ok: boolean))
---@field public toplevel               string
---@field public unstage_file           fun(self: era.m.git.Repo, file: string, callback: fun(ok: boolean))
---@field public update_index           fun(self: era.m.git.Repo, mode_bits: string, object_name: string, file: string, callback: fun(ok: boolean))

---@class era.m.git.FileInfo
---@field public has_conflicts          boolean|nil
---@field public i_crlf                 boolean|nil
---@field public mode_bits              string|nil
---@field public object_name            string|nil
---@field public relpath                string|nil
---@field public w_crlf                 boolean|nil

----------------------------------------------------------------------------------------------------
-- Buffer types
----------------------------------------------------------------------------------------------------

---@class era.m.git.buffer.ICache
---@field public attached               boolean
---@field public bufnr                  integer
---@field public changedtick            integer
---@field public compare_text           string[]|nil
---@field public compare_text_index     string[]|nil
---@field public dirty                  boolean
---@field public file                   string
---@field public force_next_update      boolean
---@field public hunks                  era.m.git.Hunk[]|nil
---@field public hunks_staged           era.m.git.Hunk[]|nil
---@field public mode_bits              string|nil
---@field public object_name            string|nil
---@field public relpath                string
---@field public repo                   era.m.git.Repo
---@field public untracked              boolean
---@field public update_debounced       stl.timer.IDisposableCallable|nil

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
---@field public previous               string|nil
---@field public previous_filename      string|nil
---@field public sha                    string
---@field public summary                string

----------------------------------------------------------------------------------------------------
-- Status types
----------------------------------------------------------------------------------------------------

---@class era.m.git.status.ICollectOpts
---@field public base                   string|nil
---@field public include_untracked      boolean|nil
---@field public workspace              string|nil

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
---@field public summary                string|nil
---@field public unstaged               table<string, boolean>
---@field public unstaged_bits          integer
---@field public unstaged_display       string

----------------------------------------------------------------------------------------------------
-- Browse types
----------------------------------------------------------------------------------------------------

---@class era.m.git.browse.IOpenOpts
---@field public branch                 string|nil
---@field public commit                 string|nil
---@field public line_end               integer|nil
---@field public line_start             integer|nil
---@field public what                   string|nil

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
---@field public workspace              string|nil

---@class era.m.git.status.IDirInfo
---@field public codes                  table<string, boolean>
---@field public display                string
---@field public stage                  era.m.git.StageState
---@field public summary                string|nil

----------------------------------------------------------------------------------------------------

return {}
