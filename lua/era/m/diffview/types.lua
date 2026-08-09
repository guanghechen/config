---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.types" ---@type string

----------------------------------------------------------------------------------------------------
-- Diffview tabtypes (defined in stl.e.TabTypeEnum)
----------------------------------------------------------------------------------------------------
-- diffview_workspace     - Git Diff view (staged/unstaged)
-- diffview_commits       - Git Log view (supports optional path filter for file history)

-- All enum types are defined in lua/__types__/stl/m/diffview.lua:
-- stl.m.diffview.LayoutTypeEnum, stl.m.diffview.PanelViewTypeEnum,
-- stl.m.diffview.PanelTypeEnum, stl.m.diffview.StageTypeEnum,
-- stl.m.diffview.WindowSlotEnum, stl.m.diffview.FiletreeLineTypeEnum,
-- stl.m.diffview.CommitsLineTypeEnum

----------------------------------------------------------------------------------------------------
-- Config types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.config
---@field public NS                     integer
---@field public FT                     table<string, string>
---@field public BUFOPTS_PANEL          table<string, any>
---@field public BUFOPTS_SBS            table<string, any>
---@field public WINOPTS_SBS            era.m.diffview.IWinopts
---@field public WINOPTS_PANEL          table<string, any>
---@field public TRACKED_WINOPTS        string[]
---@field public FILETREE_WIDTH         integer
---@field public COMMITS_WIDTH          integer
---@field public COMMITS_HEIGHT         integer
---@field public COMMITS_PER_PAGE       integer
---@field public ICONS                  { COLLAPSED: string, EXPANDED: string, FILE: string, SEPARATOR: string }
---@field public STATUS_ICONS           table<string, string>

---@class era.m.diffview.fn
---@field public open_workspace         fun(opts: { layout: stl.m.diffview.LayoutTypeEnum|nil }|nil): nil
---@field public open_file_history      fun(opts: { filepath: string|nil, layout: stl.m.diffview.LayoutTypeEnum|nil }|nil): nil
---@field public open_commits           fun(opts: { layout: stl.m.diffview.LayoutTypeEnum|nil }|nil): nil
---@field public close                  fun(): nil
---@field public refresh                fun(): nil
---@field public toggle_commits         fun(): nil
---@field public toggle_files           fun(): nil

----------------------------------------------------------------------------------------------------
-- File entry types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.IFileEntry
---@field public filepath               string                          relative path
---@field public status                 string                          git status code (A/M/D/R/?)
---@field public stage_type             stl.m.diffview.StageTypeEnum|nil
---@field public insertions             integer|nil                     added lines count
---@field public deletions              integer|nil                     deleted lines count
---@field public prev_filepath          string|nil                      previous filepath (for rename/copy)
---@field public old_object_name        string|nil                      source blob from the status snapshot
---@field public new_object_name        string|nil                      target blob from the status snapshot

----------------------------------------------------------------------------------------------------
-- Commit types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.ICommit
---@field public hash                   string                          full commit hash
---@field public abbrev_hash            string                          abbreviated hash
---@field public author                 string                          author name
---@field public date                   integer                         unix timestamp
---@field public message                string                          commit message (first line)
---@field public files                  era.m.diffview.IFileEntry[]|nil changed files (lazy loaded)
---@field public file_status            string|nil                      file status for file history (A/M/D)
---@field public filepath               string|nil                      filepath for file history
---@field public parent_filepath        string|nil                      parent filepath for rename/copy
---@field public file_insertions        integer|nil                     insertions for file history
---@field public file_deletions         integer|nil                     deletions for file history
---@field public total_files_changed    integer|nil                     total files changed for commit
---@field public total_insertions       integer|nil                     total insertions for commit
---@field public total_deletions        integer|nil                     total deletions for commit

----------------------------------------------------------------------------------------------------
-- Filetree line mapping types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.IFiletreeLineMap
---@field public type                   stl.m.diffview.FiletreeLineTypeEnum
---@field public entry                  era.m.diffview.IFileEntry|nil
---@field public stage_type             stl.m.diffview.StageTypeEnum|nil
---@field public uuid                   string|nil

----------------------------------------------------------------------------------------------------
-- Filetree node data types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.IFiletreeNodeData
---@field public basename               string
---@field public filepath               string
---@field public filetype               "directory" | "file"
---@field public fileicon               string
---@field public fileicon_hln           string
---@field public entry                  era.m.diffview.IFileEntry|nil
---@field public stage_type             stl.m.diffview.StageTypeEnum

----------------------------------------------------------------------------------------------------
-- Commits line mapping types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.ICommitsLineMap
---@field public type                   stl.m.diffview.CommitsLineTypeEnum
---@field public commit                 era.m.diffview.ICommit|nil
---@field public entry                  era.m.diffview.IFileEntry|nil

----------------------------------------------------------------------------------------------------
-- Window options types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.IWinopts
---@field public cursorbind             boolean|nil
---@field public diff                   boolean|nil
---@field public foldenable             boolean|nil
---@field public foldcolumn             string|nil
---@field public foldlevel              integer|nil
---@field public foldmethod             string|nil
---@field public scrollbind             boolean|nil
---@field public scrollopt              string[]|nil
---@field public winhl                  string|nil

----------------------------------------------------------------------------------------------------
-- State types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.IState
---@field public entries                era.m.diffview.IFileEntry[]
---@field public current_entry          era.m.diffview.IFileEntry|nil
---@field public commits                era.m.diffview.ICommit[]
---@field public current_commit         era.m.diffview.ICommit|nil
---@field public expanded_commits       table<string, boolean>

----------------------------------------------------------------------------------------------------
-- Render result types
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.IOverlay
---@field public lnum                   integer                         0-indexed line number
---@field public virt_text              [string, string][]              virtual text segments {text, hlname}[]

---@class era.m.diffview.IRenderResult
---@field public lines                  string[]
---@field public highlights             stl.t.IHighlight[]
---@field public line_map               era.m.diffview.IFiletreeLineMap[]|era.m.diffview.ICommitsLineMap[]
---@field public overlays               era.m.diffview.IOverlay[]|nil   right-aligned virtual text

----------------------------------------------------------------------------------------------------

return {}
