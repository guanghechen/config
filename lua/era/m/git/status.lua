---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.status" ---@type string

local jobs = require("era.m.git.job")

local DEFAULT_GIT_STATUS_HL = "m_ft_git_other"
local GIT_STATUS_HIGHLIGHT = {
  ["!"] = "m_ft_git_ignored",
  ["?"] = "m_ft_git_untracked",
  A = "m_ft_git_add",
  C = "m_ft_git_rename",
  D = "m_ft_git_delete",
  M = "m_ft_git_change",
  R = "m_ft_git_rename",
  T = "m_ft_git_change",
  U = "m_ft_git_unmerged",
} ---@type table<string, string>

---@class era.m.git.status
local M = {}
M.GIT_STATUS_HIGHLIGHT = GIT_STATUS_HIGHLIGHT

---@return yoz.git.StatusSnapshot
function M.empty()
  return yoz.git.empty_status()
end

---Rust owns the query and snapshot; the shared adapter owns editor scheduling.
---@param opts                          ?era.m.git.status.ICollectOpts
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with yoz.git.StatusSnapshot
function M.collect(opts, token)
  if not dot.path.is_git_repo() or (token and token:is_cancelled()) then
    return stl.c.Future.resolve(M.empty())
  end
  return jobs.run(function()
    return yoz.git.start_status({
      cwd = dot.path.workspace(),
      base = opts and opts.base,
      include_numstat = opts and opts.include_numstat,
      include_untracked = opts and opts.include_untracked,
    })
  end, token)
end

---@param info                          yoz.git.StatusInfo
---@return string|nil
local function resolve_highlight(info)
  local flags = yoz.git.codes
  if bit.band(info.codes, flags.D) ~= 0 then
    return GIT_STATUS_HIGHLIGHT.D
  end
  if bit.band(info.codes, flags.U) ~= 0 then
    return GIT_STATUS_HIGHLIGHT.U
  end
  if info.stage == "unstaged" or info.stage == "mixed" then
    return "m_ft_git_unstaged"
  end
  if info.stage == "staged" then
    return "m_ft_git_staged"
  end
  return info.summary and GIT_STATUS_HIGHLIGHT[info.summary] or nil
end

---@param filepath                      string
---@param filetype                      ?"file"|"directory"
---@return yoz.git.StatusInfo|nil
local function lookup(filepath, filetype)
  if type(filepath) ~= "string" or filepath == "" then
    return nil
  end
  return era.m.git.state.snapshot():lookup(filepath, filetype == "directory")
end

---@param filepath                      string
---@param filetype                      ?"file"|"directory"
---@return string|nil
---@return string|nil
function M.resolve(filepath, filetype)
  local info = lookup(filepath, filetype)
  if not info or info.display == "" then
    return nil, nil
  end
  return info.display, resolve_highlight(info)
end

---@param filepath                      string
---@param filetype                      ?"file"|"directory"
---@param offset                        integer
---@param highlights                    stl.t.IHighlightInline[]
---@return string
---@return string|nil
function M.calc_info(filepath, filetype, offset, highlights)
  if type(highlights) ~= "table" then
    return "", nil
  end
  local info = lookup(filepath, filetype)
  if not info or info.display == "" then
    return "", nil
  end

  highlights[#highlights + 1] = { coll = offset, colr = offset + 1, hlname = DEFAULT_GIT_STATUS_HL }
  local is_untracked = bit.band(info.codes, yoz.git.codes["?"]) ~= 0
  local staged_len = #info.staged_display
  for index = 1, #info.display do
    local char = info.display:sub(index, index)
    local hlname = GIT_STATUS_HIGHLIGHT[char] or DEFAULT_GIT_STATUS_HL
    if char == "U" and is_untracked then
      hlname = GIT_STATUS_HIGHLIGHT["?"]
    elseif index <= staged_len and char ~= "D" and char ~= "U" then
      hlname = "m_ft_git_staged"
    end
    highlights[#highlights + 1] = { coll = offset + index, colr = offset + index + 1, hlname = hlname }
  end
  return " " .. info.display, resolve_highlight(info)
end

return M
