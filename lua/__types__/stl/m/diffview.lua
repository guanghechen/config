---@meta

---@alias stl.m.diffview.LayoutTypeEnum
---| "diff1"
---| "diff2_hor"
---| "diff2_ver"
---| "diff3_hor"
---| "diff3_ver"
---| "diff3_mixed"
---| "diff4_mixed"

---@alias stl.m.diffview.PanelViewTypeEnum
---| "tree"
---| "list"

---@alias stl.m.diffview.PanelTypeEnum
---| "filetree"
---| "commits"
---| "sbs_left"
---| "sbs_right"

---@alias stl.m.diffview.StageTypeEnum
---| "staged"
---| "unstaged"

---@alias stl.m.diffview.WindowSlotEnum
---| "a"                                    -- old version / BASE
---| "b"                                    -- LOCAL (main window)
---| "c"                                    -- REMOTE
---| "d"                                    -- STAGE1 (4-way merge)

---@alias stl.m.diffview.FiletreeLineTypeEnum
---| "header"
---| "separator"
---| "file"
---| "directory"

---@alias stl.m.diffview.CommitsLineTypeEnum
---| "commit"
---| "directory"
---| "file"

---@alias stl.m.diffview.CommitsPanelLayoutEnum
---| "left"
---| "top"
