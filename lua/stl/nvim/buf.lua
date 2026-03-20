---@alias stl.nvim.buf.TypeEnum
---| ""
---| "acwrite"
---| "help"
---| "nofile"
---| "nowrite"
---| "quickfix"
---| "terminal"
---| "prompt"

---@class stl.nvim.buf.Types
local Types = {
  EMPTY = "",
  ACWRITE = "acwrite",
  HELP = "help",
  NOFILE = "nofile",
  NOWRITE = "nowrite",
  QUICKFIX = "quickfix",
  TERMINAL = "terminal",
  PROMPT = "prompt",
}

local buftype_attrs = {
  sourcefile = {
    [Types.EMPTY] = true,
    [Types.ACWRITE] = true,
    [Types.NOFILE] = true,
    [Types.NOWRITE] = true,
  },
}

local filepath_to_bufnr = {} ---@type table<string, integer>
local filepath_fallback_to_bufnr = {} ---@type table<string, integer>
local bufnr_to_filepath = {} ---@type table<integer, string>

---@param filepath                      string|nil
---@return string
local function normalize_bufpath(filepath)
  if type(filepath) ~= "string" or filepath == "" then
    return ""
  end

  -- Keep special URI-like buffer names (e.g. diffview://null) untouched.
  if filepath:match("^[%w+.-]+://") then
    return filepath
  end

  local last = filepath:sub(-1) ---@type string
  local keep_trailing_slash = last == "/" or last == "\\" ---@type boolean
  return dot.path.normalize(filepath, keep_trailing_slash, "/")
end

---@param filepath                      string
---@return string|nil
local function make_fallback_bufpath(filepath)
  if not stl.env.IS_WIN then
    return nil
  end

  -- Keep URI-like names untouched, fallback only applies to local filepaths.
  if filepath:match("^[%w+.-]+://") then
    return nil
  end

  local fallback = filepath:lower() ---@type string
  return fallback ~= filepath and fallback or nil
end

---@class stl.nvim.buf
local M = {}

M.Types = vim.deepcopy(Types)

---@param bufnr                         ?integer
---@return nil
function M.close(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

---@param bufnr                         ?integer
---@return boolean
function M.is_editable(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  return vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" and vim.api.nvim_get_option_value("modifiable", { buf = bufnr }) and not vim.api.nvim_get_option_value("readonly", { buf = bufnr })
end

---@param bufnr                         ?integer
---@return boolean
function M.is_sourcefile(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
  if buftype_attrs.sourcefile[buftype] ~= true then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  if stl.filetype.is_not_sourcefile(filetype) then
    return false
  end

  return true
end

---@param bufnr                         integer
---@return boolean
function M.is_valid(bufnr)
  return bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

---@return table<string, integer>
function M.filepath2bufnr()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local result = {} ---@type table<string, integer>

  for _, bufnr in ipairs(bufnrs) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local key = normalize_bufpath(filepath) ---@type string
    if key ~= "" then
      result[key] = bufnr
    end
  end
  return result
end

---@return table<string, integer>
function M.get_loaded_bufnrs()
  local result = {} ---@type table<string, integer>
  for filepath, bufnr in pairs(filepath_to_bufnr) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      result[filepath] = bufnr
      local fallback = make_fallback_bufpath(filepath) ---@type string|nil
      if fallback ~= nil and result[fallback] == nil then
        result[fallback] = bufnr
      end
    end
  end
  return result
end

---@param filepath_to_bufnr_map         table<string, integer>
---@param filepath                      string
---@return integer|nil
function M.lookup_bufnr(filepath_to_bufnr_map, filepath)
  local key = normalize_bufpath(filepath) ---@type string
  if key == "" then
    return nil
  end

  local bufnr = filepath_to_bufnr_map[key] ---@type integer|nil
  if bufnr ~= nil then
    return bufnr
  end

  local fallback = make_fallback_bufpath(key) ---@type string|nil
  if fallback ~= nil then
    return filepath_to_bufnr_map[fallback]
  end
end

---@param filepath                      string
---@return integer|nil
function M.locate_bufnr(filepath)
  local key = normalize_bufpath(filepath) ---@type string
  if key == "" then
    return nil
  end

  local bufnr = filepath_to_bufnr[key] ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  filepath_to_bufnr[key] = nil
  if bufnr ~= nil then
    bufnr_to_filepath[bufnr] = nil
  end

  local fallback = make_fallback_bufpath(key) ---@type string|nil
  if fallback ~= nil then
    bufnr = filepath_fallback_to_bufnr[fallback]
    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
      return bufnr
    end
    filepath_fallback_to_bufnr[fallback] = nil
    if bufnr ~= nil then
      bufnr_to_filepath[bufnr] = nil
    end
  end

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, c_bufnr in ipairs(bufnrs) do
    if vim.api.nvim_buf_is_valid(c_bufnr) then
      local c_filepath = vim.api.nvim_buf_get_name(c_bufnr) ---@type string
      local c_key = normalize_bufpath(c_filepath) ---@type string
      local c_fallback = make_fallback_bufpath(c_key) ---@type string|nil
      if c_key == key or (fallback ~= nil and c_fallback == fallback) then
        filepath_to_bufnr[c_key] = c_bufnr
        if c_fallback ~= nil then
          filepath_fallback_to_bufnr[c_fallback] = c_bufnr
        end
        bufnr_to_filepath[c_bufnr] = c_key
        return c_bufnr
      end
    end
  end
end

---@param bufnr                         integer
---@param filepath                      string
---@return nil
function M.on_buf_open(bufnr, filepath)
  local key = normalize_bufpath(filepath) ---@type string
  if bufnr < 1 or key == "" then
    return
  end

  local old_filepath = bufnr_to_filepath[bufnr] ---@type string|nil
  if old_filepath ~= nil and old_filepath ~= key then
    filepath_to_bufnr[old_filepath] = nil
    local old_fallback = make_fallback_bufpath(old_filepath) ---@type string|nil
    if old_fallback ~= nil then
      filepath_fallback_to_bufnr[old_fallback] = nil
    end
  end

  filepath_to_bufnr[key] = bufnr
  local fallback = make_fallback_bufpath(key) ---@type string|nil
  if fallback ~= nil then
    filepath_fallback_to_bufnr[fallback] = bufnr
  end
  bufnr_to_filepath[bufnr] = key
end

---@param bufnr                         integer
---@return nil
function M.on_buf_close(bufnr)
  local old_filepath = bufnr_to_filepath[bufnr] ---@type string|nil
  if old_filepath ~= nil then
    filepath_to_bufnr[old_filepath] = nil
    local old_fallback = make_fallback_bufpath(old_filepath) ---@type string|nil
    if old_fallback ~= nil then
      filepath_fallback_to_bufnr[old_fallback] = nil
    end
    bufnr_to_filepath[bufnr] = nil
  end
end

---@return string
function M.retrieve_selected_text()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
  if buftype == Types.TERMINAL or buftype == Types.PROMPT then
    return ""
  end

  local saved_reg = vim.fn.getreg("v") ---@type string
  vim.cmd([[noautocmd sil norm! "vy]])

  local selected_text = vim.fn.getreg("v") ---@type string
  vim.fn.setreg("v", saved_reg)
  return selected_text or ""
end

---@return integer
---@return integer
function M.retrieve_visual_lnum_range()
  local start_pos = vim.fn.getpos("v") -- visual selection start
  local end_pos = vim.fn.getpos(".") -- visual selection end (cursor)

  local lnum_start = start_pos[2] ---@type integer
  local lnum_end = end_pos[2] ---@type integer

  if lnum_start < lnum_end then
    return lnum_start, lnum_end
  end
  return lnum_end, lnum_start
end

---@return integer
---@return integer
---@return integer
---@return integer
function M.retrieve_visual_range()
  local s_pos = vim.fn.getpos("v") -- visual selection start
  local e_pos = vim.fn.getpos(".") -- visual selection end (cursor)

  local s_lnum = s_pos[2] ---@type integer
  local s_col = s_pos[3] ---@type integer
  local e_lnum = e_pos[2] ---@type integer
  local e_col = e_pos[3] ---@type integer

  if s_lnum < e_lnum then
    return s_lnum, s_col, e_lnum, e_col
  end

  if s_lnum == e_lnum and s_col < e_col then
    return s_lnum, s_col, e_lnum, e_col
  end

  return e_lnum, e_col, s_lnum, s_col
end

---@param bufnr                         integer
---@param lnum_start                    integer
---@param col_start                     integer
---@param lnum_end                      integer
---@param col_end                       integer
---@return string[]
function M.retrieve_visual_range_lines(bufnr, lnum_start, col_start, lnum_end, col_end)
  local lines = vim.api.nvim_buf_get_lines(bufnr, lnum_start - 1, lnum_end, false) ---@type string[]
  local N = #lines ---@type integer

  if N == 0 then
    return {}
  end

  if N == 1 then
    lines[1] = string.sub(lines[1], col_start, col_end)
  end

  if N > 1 then
    lines[1] = string.sub(lines[1], col_start, -1)
    lines[N] = string.sub(lines[N], 1, col_end)
  end

  return lines
end

return M
