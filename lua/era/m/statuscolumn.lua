---@see https://github.com/folke/snacks.nvim/blob/85b8ec210975aa137af4b7bef1fb7b7098be331a/lua/snacks/statuscolumn.lua

---@class era.m.statuscolumn.IConfig
---@field public left                   era.m.statuscolumn.IComponents
---@field public right                  era.m.statuscolumn.IComponents
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

---@alias era.m.statuscolumn.IComponents
---| era.m.statuscolumn.SignType[]
---| fun(winnr: number, bufnr: number,lnum:number): era.m.statuscolumn.SignType[]

---@alias era.m.statuscolumn.IWanted table<era.m.statuscolumn.SignType, boolean>

---@alias era.m.statuscolumn.SignType
---| "mark"
---| "sign"
---| "fold"
---| "git"

---@class era.m.statuscolumn.ISign
---@field public type                   era.m.statuscolumn.SignType
---@field public text                   string
---@field public texthl                 string|nil
---@field public name                   string|nil
---@field public priority               number|nil

---@class era.m.statuscolumn.IFoldInfo
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
---@return era.m.statuscolumn.IFoldInfo|nil
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
  return C.fold_info(wp, lnum) ---@type era.m.statuscolumn.IFoldInfo
end

-- Cache for signs per buffer and line
local sign_cache = {} ---@type table<number,table<number, era.m.statuscolumn.ISign[]>>
local icon_cache = {} ---@type table<string, string>
local cache = {} ---@type table<string, string>

local did_setup = false

---@return nil
local function setup()
  if not did_setup then
    did_setup = true
    local timer = assert(vim.uv.new_timer())
    timer:start(config.refresh, config.refresh, function()
      sign_cache = {}
      cache = {}
    end)
  end
end

---@param signs_by_type                 table<era.m.statuscolumn.SignType, era.m.statuscolumn.ISign>
---@param types                         era.m.statuscolumn.SignType[]
---@return era.m.statuscolumn.ISign|nil
local function find_sign(signs_by_type, types)
  for _, t in ipairs(types) do
    local sign = signs_by_type[t] ---@type era.m.statuscolumn.ISign|nil
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

-- Returns a list of regular and extmark signs sorted by priority (low to high)
---@param bufnr                         integer
---@param wanted                        era.m.statuscolumn.IWanted
---@return table<integer, era.m.statuscolumn.ISign[]>
local function get_buf_signs(bufnr, wanted)
  local signs_map = {} ---@type table<integer, era.m.statuscolumn.ISign[]>

  if wanted.sign or wanted.git then
    -- Get extmark signs (includes both legacy and extmark signs in nvim 0.10+)
    local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true, type = "sign" })
    for _, extmark in ipairs(extmarks) do
      local lnum = extmark[2] + 1
      local name = extmark[4].sign_hl_group or extmark[4].sign_name or ""
      ---@type era.m.statuscolumn.ISign
      local sign = {
        name = name,
        type = is_git_sign(name) and "git" or "sign",
        text = extmark[4].sign_text or "",
        texthl = extmark[4].sign_hl_group,
        priority = extmark[4].priority or 0,
      }

      signs_map[lnum] = signs_map[lnum] or {}
      if wanted[sign.type] then
        table.insert(signs_map[lnum], sign)
      end
    end
  end

  -- Add marks
  if wanted.mark then
    local marks = vim.fn.getmarklist(bufnr)
    vim.list_extend(marks, vim.fn.getmarklist())
    for _, mark in ipairs(marks) do
      if mark.pos[1] == bufnr and mark.mark:match("[a-zA-Z]") then
        ---@type era.m.statuscolumn.ISign
        local sign = { type = "mark", text = string.sub(mark.mark, 2), texthl = "StatusColumnMark" }
        local lnum = mark.pos[2]
        signs_map[lnum] = signs_map[lnum] or {}
        table.insert(signs_map[lnum], sign)
      end
    end
  end

  return signs_map
end

-- Returns a list of regular and extmark signs sorted by priority (high to low)
---@param winnr                         integer
---@param bufnr                         integer
---@param lnum                          integer
---@param wanted                        era.m.statuscolumn.IWanted
---@return era.m.statuscolumn.ISign[]
local function line_signs(winnr, bufnr, lnum, wanted)
  local buf_signs = sign_cache[bufnr] ---@type table<integer, era.m.statuscolumn.ISign[]>|nil
  if not buf_signs then
    buf_signs = get_buf_signs(bufnr, wanted)
    sign_cache[bufnr] = buf_signs
  end
  local signs = buf_signs[lnum] or {} ---@type era.m.statuscolumn.ISign[]

  -- Get fold signs
  if wanted.fold then
    local info = fold_info(winnr, lnum)
    if info and info.level > 0 then
      if info.lines > 0 then
        ---@type era.m.statuscolumn.ISign
        local sign = { type = "fold", text = stl.icon.fillchars.foldclose, texthl = "Folded" }
        signs[#signs + 1] = sign
      elseif config.folds.open and info.start == lnum then
        ---@type era.m.statuscolumn.ISign
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

---@param sign                          ?era.m.statuscolumn.ISign
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
  setup()

  local winnr = vim.g.statusline_winid ---@type integer
  local nu = vim.wo[winnr].number ---@type boolean
  local rnu = vim.wo[winnr].relativenumber ---@type boolean
  local show_signs = vim.v.virtnum == 0 and vim.wo[winnr].signcolumn ~= "no" ---@type boolean
  if not (show_signs or nu or rnu) then
    return ""
  end

  local left_c = config.left --[[@as era.m.statuscolumn.SignType[] ]]
  local right_c = config.right --[[@as era.m.statuscolumn.SignType[] ]]

  ---@type era.m.statuscolumn.IWanted
  local wanted = { sign = show_signs }
  for _, component in ipairs(left_c) do
    wanted[component] = wanted[component] ~= false
  end
  for _, component in ipairs(right_c) do
    wanted[component] = wanted[component] ~= false
  end

  local components = { "", "", "" } ---@type string[]
  if (nu or rnu) and vim.v.virtnum == 0 then
    local num ---@type number
    if rnu and nu and vim.v.relnum == 0 then
      num = vim.v.lnum
    elseif rnu then
      num = vim.v.relnum
    else
      num = vim.v.lnum
    end
    components[2] = "%=" .. num .. " "
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local show_folds = vim.v.virtnum == 0 and vim.wo[winnr].foldcolumn ~= "0" ---@type boolean
  if show_signs or show_folds then
    local signs = line_signs(winnr, bufnr, vim.v.lnum, wanted) ---@type era.m.statuscolumn.ISign[]

    if #signs > 0 then
      local signs_by_type = {} ---@type table<era.m.statuscolumn.SignType, era.m.statuscolumn.ISign>
      for _, sign in ipairs(signs) do
        signs_by_type[sign.type] = signs_by_type[sign.type] or sign
      end

      local left = find_sign(signs_by_type, left_c)
      local right = find_sign(signs_by_type, right_c)

      local git = signs_by_type.git
      if git and left and left.type == "fold" then
        left.texthl = git.texthl
      end
      if git and right and right.type == "fold" then
        right.texthl = git.texthl
      end

      components[1] = left and get_icon(left) or "  " -- left
      components[3] = right and get_icon(right) or "  " -- right
    else
      components[1] = "  "
      components[3] = "  "
    end
  end
  components[1] = vim.b[bufnr].era_statuscolumn_left ~= false and components[1] or ""
  components[3] = vim.b[bufnr].era_statuscolumn_right ~= false and components[3] or ""

  local ret = table.concat(components, "")
  return "%@v:lua.era.m.statuscolumn.click_fold@" .. ret .. "%T"
end

---@class era.m.statuscolumn
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

---@return nil
function M.dressing()
  vim.o.statuscolumn = "%!v:lua.era.m.statuscolumn.statuscolumn()"
end

return M
