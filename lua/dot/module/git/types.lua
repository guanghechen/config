---@class dot.module.git.BlameInfo
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

---@class dot.module.git.browse.IOpenOpts
---@field public branch                 string|nil
---@field public commit                 string|nil
---@field public line_end               integer|nil
---@field public line_start             integer|nil
---@field public what                   string|nil

---@class dot.module.git.buffer.ICache
---@field public attached               boolean
---@field public bufnr                  integer
---@field public changedtick            integer
---@field public compare_text           string[]|nil
---@field public compare_text_index     string[]|nil
---@field public dirty                  boolean
---@field public file                   string
---@field public force_next_update      boolean
---@field public hunks                  dot.module.git.Hunk[]|nil
---@field public hunks_staged           dot.module.git.Hunk[]|nil
---@field public mode_bits              string|nil
---@field public object_name            string|nil
---@field public relpath                string
---@field public repo                   dot.module.git.Repo
---@field public untracked              boolean
---@field public update_debounced       ark.timer.IDisposableCallable|nil

---@class dot.module.git.cmd.IRunAsyncOpts
---@field public cwd                    string|nil
---@field public on_exit                fun(proc: ark.c.Proc, err: boolean)|nil
---@field public on_stderr              fun(proc: ark.c.Proc, data: string)|nil
---@field public on_stdout              fun(proc: ark.c.Proc, data: string)|nil
---@field public stdin                  string|nil
---@field public timeout                integer|nil

---@class dot.module.git.cmd.IRunSyncOpts
---@field public cwd                    string|nil
---@field public stdin                  string|nil

---@class dot.module.git.FileInfo
---@field public has_conflicts          boolean|nil
---@field public i_crlf                 boolean|nil
---@field public mode_bits              string|nil
---@field public object_name            string|nil
---@field public relpath                string|nil
---@field public w_crlf                 boolean|nil

---@class dot.module.git.Hunk
---@field public added                  dot.module.git.HunkNode
---@field public head                   string
---@field public removed                dot.module.git.HunkNode
---@field public type                   dot.module.git.HunkType
---@field public vend                   integer

---@class dot.module.git.HunkNode
---@field public count                  integer
---@field public lines                  string[]
---@field public no_nl_at_eof           boolean|nil
---@field public start                  integer

---@class dot.module.git.HunkSummary
---@field public added                  integer
---@field public changed                integer
---@field public removed                integer

---@alias dot.module.git.HunkType
---| "add"
---| "change"
---| "delete"

---@class dot.module.git.Repo
---@field public abbrev_head            string
---@field public add_intent_to_add      fun(self: dot.module.git.Repo, file: string, callback: fun(ok: boolean))
---@field public apply_patch            fun(self: dot.module.git.Repo, patch: string, reverse: boolean|nil, callback: fun(ok: boolean, err: string|nil))
---@field public detached               boolean
---@field public get_file_info          fun(self: dot.module.git.Repo, file: string, callback: fun(info: dot.module.git.FileInfo|nil))
---@field public get_relpath            fun(self: dot.module.git.Repo, file: string): string
---@field public get_show_text          fun(self: dot.module.git.Repo, object: string, callback: fun(lines: string[]|nil))
---@field public gitdir                 string
---@field public hash_object            fun(self: dot.module.git.Repo, file: string, lines: string[], callback: fun(hash: string|nil))
---@field public refresh_head           fun(self: dot.module.git.Repo, callback: fun()|nil)
---@field public reset_file             fun(self: dot.module.git.Repo, file: string, callback: fun(ok: boolean))
---@field public stage_file             fun(self: dot.module.git.Repo, file: string, callback: fun(ok: boolean))
---@field public toplevel               string
---@field public unstage_file           fun(self: dot.module.git.Repo, file: string, callback: fun(ok: boolean))
---@field public update_index           fun(self: dot.module.git.Repo, mode_bits: string, object_name: string, file: string, callback: fun(ok: boolean))

---@class dot.module.git.Sign
---@field public count                  integer|nil
---@field public lnum                   integer
---@field public type                   dot.module.git.SignType

---@alias dot.module.git.SignType
---| "add"
---| "change"
---| "changedelete"
---| "delete"
---| "topdelete"
---| "untracked"

---@alias dot.module.git.StageState
---| "mixed"
---| "staged"
---| "unstaged"
---| nil

---@class dot.module.git.state.ICache
---@field public dir_codes              table<string, table<string, boolean>>
---@field public dir_display            table<string, string>
---@field public dir_stage              table<string, dot.module.git.StageState>
---@field public dir_summary            table<string, string|nil>
---@field public file_display           table<string, string>
---@field public file_stage             table<string, dot.module.git.StageState>
---@field public file_summary           table<string, string|nil>
---@field public ignored                table<string, boolean>
---@field public initialized            boolean
---@field public last_refresh           integer
---@field public status_table           table<string, dot.module.git.StatusEntry>
---@field public workspace              string|nil

---@class dot.module.git.state.dirinfo
---@field public codes                  table<string, boolean>
---@field public stage                  dot.module.git.StageState
---@field public summary                string|nil

---@class dot.module.git.status.ICollectOpts
---@field public base                   string|nil
---@field public include_untracked      boolean|nil
---@field public workspace              string|nil

---@class dot.module.git.StatusEntry
---@field public categories             table<string, boolean>
---@field public codes                  table<string, boolean>
---@field public display                string
---@field public path                   string
---@field public relative               string
---@field public stage                  dot.module.git.StageState
---@field public staged                 table<string, boolean>
---@field public staged_bits            integer
---@field public staged_display         string
---@field public summary                string|nil
---@field public unstaged               table<string, boolean>
---@field public unstaged_bits          integer
---@field public unstaged_display       string

return {}
