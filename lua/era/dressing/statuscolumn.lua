---@see https://github.com/folke/snacks.nvim/blob/85b8ec210975aa137af4b7bef1fb7b7098be331a/lua/snacks/statuscolumn.lua

local __module_name__ = "era.dressing.statuscolumn" ---@type string
local initialized = false ---@type boolean

---@class era.dressing.statuscolumn.IConfig
---@field public left                   era.dressing.statuscolumn.IComponents
---@field public right                  era.dressing.statuscolumn.IComponents
---@field public refresh                integer
---@field public folds                  { open: boolean, git_hl: boolean }
local config = {
  left = { "mark", "sign" }, -- priority of signs on the left (high to low)
  right = { "fold", "git" }, -- priority of signs on the right (high to low)
  refresh = 50, -- refresh at most every 50ms
  folds = {
    open = true, -- show open fold icons
    git_hl = true, -- use Git Signs hl for fold icons
  },
}

---@alias era.dressing.statuscolumn.IComponents
---| era.dressing.statuscolumn.SignType[]
---| fun(winnr: number, bufnr: number,lnum:number): era.dressing.statuscolumn.SignType[]

---@alias era.dressing.statuscolumn.IWanted table<era.dressing.statuscolumn.SignType, boolean>

---@alias era.dressing.statuscolumn.SignType
---| "mark"
---| "sign"
---| "fold"
---| "git"

---@class era.dressing.statuscolumn.ISign
---@field public type                   era.dressing.statuscolumn.SignType
---@field public text                   string
---@field public texthl                 string|nil
---@field public name                   string|nil
---@field public priority               number|nil

---@class era.dressing.statuscolumn.IFoldInfo
---@field public start                  number Line number where deepest fold starts
---@field public level                  number Fold level, when zero other fields are N/A
---@field public llevel                 number Lowest level that starts in v:lnum
---@field public lines                  number Number of lines from v:lnum to end of closed fold

---@type ffi.namespace*
local C

local function _ffi()
  if not C then
    local ffi = require("ffi")
    ffi.cdef([[
      typedef struct {} Error;
      typedef struct {} win_T;
      typedef struct {
        int start;  // line number where deepest fold starts
        int level;  // fold level, when zero other fields are N/A
        int llevel; // lowest level that starts in v:lnum
        int lines;  // number of lines from v:lnum to end of closed fold
      } foldinfo_T;
      foldinfo_T fold_info(win_T* wp, int lnum);
      win_T *find_window_by_handle(int Window, Error *err);
    ]])
    C = ffi.C
  end
  return C
end

---@param winnr                         number
---@param lnum                          number
---@return era.dressing.statuscolumn.IFoldInfo|nil
local function fold_info(winnr, lnum)
  pcall(_ffi)
  if not C then
    return
  end
  local ffi = require("ffi")
  local err = ffi.new("Error")
  local wp = C.find_window_by_handle(winnr, err)
  if wp == nil then
    return
  end
  return C.fold_info(wp, lnum) ---@type era.dressing.statuscolumn.IFoldInfo
end

-- Cache for signs per buffer and line
local sign_cache = {} ---@type table<number,table<number, era.dressing.statuscolumn.ISign[]>>
local icon_cache = {} ---@type table<string, string>
local cache = {} ---@type table<string, string>

local cache_timer ---@type uv.uv_timer_t|nil

---@return nil
local function schedule_cache_expiration()
  if cache_timer == nil then
    cache_timer = assert(vim.uv.new_timer())
  elseif cache_timer:is_active() then
    return
  end

  cache_timer:start(config.refresh, 0, function()
    sign_cache = {}
    cache = {}
  end)
end

---@param signs_by_type                 table<era.dressing.statuscolumn.SignType, era.dressing.statuscolumn.ISign>
---@param types                         era.dressing.statuscolumn.SignType[]
---@return era.dressing.statuscolumn.ISign|nil
local function find_sign(signs_by_type, types)
  for _, t in ipairs(types) do
    local sign = signs_by_type[t] ---@type era.dressing.statuscolumn.ISign|nil
    if sign ~= nil then
      return sign
    end
  end
end

---@param name                          string
---@return boolean
local function is_git_sign(name)
  return name:find("^m_git_sign_") ~= nil
end

-- Returns buffer signs grouped by line
---@param bufnr                         integer
---@return table<integer, era.dressing.statuscolumn.ISign[]>
local function collect_buf_signs(bufnr)
  local signs_by_lnum = {} ---@type table<integer, era.dressing.statuscolumn.ISign[]>

  -- Get extmark signs (includes both legacy and extmark signs in nvim 0.10+)
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true, type = "sign" })
  for _, extmark in ipairs(extmarks) do
    local lnum = extmark[2] + 1
    local name = extmark[4].sign_hl_group or extmark[4].sign_name or ""
    ---@type era.dressing.statuscolumn.ISign
    local sign = {
      name = name,
      type = is_git_sign(name) and "git" or "sign",
      text = extmark[4].sign_text or "",
      texthl = extmark[4].sign_hl_group,
      priority = extmark[4].priority or 0,
    }

    signs_by_lnum[lnum] = signs_by_lnum[lnum] or {}
    table.insert(signs_by_lnum[lnum], sign)
  end

  -- Add marks
  local marks = vim.fn.getmarklist(bufnr)
  vim.list_extend(marks, vim.fn.getmarklist())
  for _, mark in ipairs(marks) do
    if mark.pos[1] == bufnr and mark.mark:match("[a-zA-Z]") then
      ---@type era.dressing.statuscolumn.ISign
      local sign = { type = "mark", text = string.sub(mark.mark, 2), texthl = "StatusColumnMark" }
      local lnum = mark.pos[2]
      signs_by_lnum[lnum] = signs_by_lnum[lnum] or {}
      table.insert(signs_by_lnum[lnum], sign)
    end
  end

  return signs_by_lnum
end

-- Returns wanted signs for a line sorted by priority (high to low)
---@param winnr                         integer
---@param bufnr                         integer
---@param lnum                          integer
---@param wanted                        era.dressing.statuscolumn.IWanted
---@return era.dressing.statuscolumn.ISign[]
local function line_signs(winnr, bufnr, lnum, wanted)
  local signs_by_lnum = sign_cache[bufnr] ---@type table<integer, era.dressing.statuscolumn.ISign[]>|nil
  if not signs_by_lnum then
    signs_by_lnum = collect_buf_signs(bufnr)
    sign_cache[bufnr] = signs_by_lnum
  end
  local signs = {} ---@type era.dressing.statuscolumn.ISign[]
  for _, sign in ipairs(signs_by_lnum[lnum] or {}) do
    if wanted[sign.type] then
      signs[#signs + 1] = sign
    end
  end

  -- Get fold signs
  if wanted.fold then
    local info = fold_info(winnr, lnum)
    if info and info.level > 0 then
      if info.lines > 0 then
        ---@type era.dressing.statuscolumn.ISign
        local sign = { type = "fold", text = stl.icon.fillchars.foldclose, texthl = "Folded" }
        signs[#signs + 1] = sign
      elseif config.folds.open and info.start == lnum then
        ---@type era.dressing.statuscolumn.ISign
        local sign = { type = "fold", text = stl.icon.fillchars.foldopen }
        signs[#signs + 1] = sign
      end
    end
  end

  -- Sort by priority (high to low)
  table.sort(signs, function(a, b)
    return (a.priority or 0) > (b.priority or 0)
  end)
  return signs
end

---@param sign                          ?era.dressing.statuscolumn.ISign
---@return string
local function get_icon(sign)
  if not sign then
    return "  "
  end

  local key = (sign.text or "") .. (sign.texthl or "")
  if icon_cache[key] then
    return icon_cache[key]
  end
  local text = vim.fn.strcharpart(sign.text or "", 0, 2) ---@type string
  text = text .. string.rep(" ", 2 - vim.fn.strchars(text))
  icon_cache[key] = sign.texthl and ("%#" .. sign.texthl .. "#" .. text .. "%*") or text
  return icon_cache[key]
end

---@return string
local function statuscolumn()
  schedule_cache_expiration()

  local winnr = vim.g.statusline_winid ---@type integer
  local nu = vim.api.nvim_get_option_value("number", { win = winnr }) ---@type boolean
  local rnu = vim.api.nvim_get_option_value("relativenumber", { win = winnr }) ---@type boolean
  local show_signs = vim.v.virtnum == 0 and vim.api.nvim_get_option_value("signcolumn", { win = winnr }) ~= "no" ---@type boolean
  if not (show_signs or nu or rnu) then
    return ""
  end

  local left_c = config.left --[[@as era.dressing.statuscolumn.SignType[] ]]
  local right_c = config.right --[[@as era.dressing.statuscolumn.SignType[] ]]

  ---@type era.dressing.statuscolumn.IWanted
  local wanted = { sign = show_signs }
  for _, component in ipairs(left_c) do
    wanted[component] = wanted[component] ~= false
  end
  for _, component in ipairs(right_c) do
    wanted[component] = wanted[component] ~= false
  end

  local components = { "", "", "" } ---@type string[]
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local show_folds = vim.v.virtnum == 0 and vim.api.nvim_get_option_value("foldcolumn", { win = winnr }) ~= "0" ---@type boolean
  local git_hl ---@type string|nil

  if show_signs or show_folds then
    local signs = line_signs(winnr, bufnr, vim.v.lnum, wanted) ---@type era.dressing.statuscolumn.ISign[]

    if #signs > 0 then
      local signs_by_type = {} ---@type table<era.dressing.statuscolumn.SignType, era.dressing.statuscolumn.ISign>
      for _, sign in ipairs(signs) do
        signs_by_type[sign.type] = signs_by_type[sign.type] or sign
      end

      local left = find_sign(signs_by_type, left_c)
      local right = find_sign(signs_by_type, right_c)

      local git = signs_by_type.git
      if git then
        git_hl = git.texthl
        if left and left.type == "fold" then
          left.texthl = git.texthl
        end
        if right and right.type == "fold" then
          right.texthl = git.texthl
        end
      end

      components[1] = left and get_icon(left) or "  " -- left
      components[3] = right and get_icon(right) or "  " -- right
    else
      components[1] = "  "
      components[3] = "  "
    end
  end

  if (nu or rnu) and vim.v.virtnum == 0 then
    local num ---@type number
    if rnu and nu and vim.v.relnum == 0 then
      num = vim.v.lnum
    elseif rnu then
      num = vim.v.relnum
    else
      num = vim.v.lnum
    end
    if git_hl then
      components[2] = "%#" .. git_hl .. "#%=" .. num .. " %*"
    else
      components[2] = "%=" .. num .. " "
    end
  end
  components[1] = vim.b[bufnr].era_statuscolumn_left ~= false and components[1] or ""
  components[3] = vim.b[bufnr].era_statuscolumn_right ~= false and components[3] or ""

  local ret = table.concat(components, "")
  return "%@v:lua.era.dressing.statuscolumn.click_fold@" .. ret .. "%T"
end

---@class era.dressing.statuscolumn
local M = {}

---@return nil
function M.click_fold()
  local pos = vim.fn.getmousepos()
  vim.api.nvim_win_set_cursor(pos.winid, { pos.line, 1 })
  vim.api.nvim_win_call(pos.winid, function()
    if vim.fn.foldlevel(pos.line) > 0 then
      vim.cmd("normal! za")
    end
  end)
end

---@return string
function M.statuscolumn()
  local winnr = vim.g.statusline_winid
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local key = ("%d:%d:%d:%d:%d"):format(winnr, bufnr, vim.v.lnum, vim.v.virtnum ~= 0 and 1 or 0, vim.v.relnum)
  if cache[key] then
    return cache[key]
  end

  local ok, result = pcall(statuscolumn)
  if ok then
    cache[key] = result
    return result
  end
  return ""
end

--- Initialize the default and current-window expression once, preserving later overrides.
---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  vim.api.nvim_set_option_value("statuscolumn", "%!v:lua." .. __module_name__ .. ".statuscolumn()", {})
end

return M
