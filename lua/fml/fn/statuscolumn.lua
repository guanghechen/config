---! see https://github.com/folke/snacks.nvim/blob/be8feef4ab584f50aaa96b69d50b3f86a35aacff/lua/snacks/statuscolumn.lua#L1

---@class fml.fn.statuscolumn.config
local config = {
  left = { "mark", "sign" }, -- priority of signs on the left (high to low)
  right = { "fold", "git" }, -- priority of signs on the right (high to low)
  folds = {
    open = true, -- show open fold icons
    git_hl = true, -- use Git Signs hl for fold icons
  },
  git = {
    -- patterns to match Git signs
    patterns = { "GitSign", "MiniDiffSign" },
  },
  refresh = 50, -- refresh at most every 50ms
}

---@alias fml.fn.statuscolumn.SignType
---| "mark"
---| "sign"
---| "fold"
---| "git"

---@class fml.fn.statuscolumn.ISign
---@field public type                   fml.fn.statuscolumn.SignType
---@field public name                   ?string
---@field public text                   string
---@field public texthl                 ?string
---@field public priority               number

-- Cache for signs per buffer and line
---@type table<number,table<number, fml.fn.statuscolumn.ISign>>
local cache = {}

local did_setup = false

---@return nil
local function setup()
  if not did_setup then
    did_setup = true
    local timer = assert((vim.uv or vim.loop).new_timer())
    timer:start(config.refresh, config.refresh, function()
      cache = {}
    end)
  end
end

---@param signs                         fml.fn.statuscolumn.ISign[]
---@param types                         fml.fn.statuscolumn.SignType[]
---@return fml.fn.statuscolumn.ISign|nil
local function find_sign(signs, types)
  for _, t in ipairs(types) do
    for _, s in ipairs(signs) do
      if s.type == t then
        return s
      end
    end
  end
  return nil
end

---@param name                          string
---@return boolean
local function is_git_sign(name)
  for _, pattern in ipairs(config.git.patterns) do
    if name:find(pattern) then
      return true
    end
  end
  return false
end

-- Returns a list of regular and extmark signs sorted by priority (low to high)
---@param bufnr                         integer
---@return table<integer, fml.fn.statuscolumn.ISign[]>
local function buf_signs(bufnr)
  if cache[bufnr] then
    return cache[bufnr]
  end

  local signs_map = {} ---@type table<integer, fml.fn.statuscolumn.ISign[]>

  -- Get extmark signs
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true, type = "sign" })
  for _, extmark in pairs(extmarks) do
    local lnum = extmark[2] + 1
    local name = extmark[4].sign_hl_group or extmark[4].sign_name or ""

    ---@type fml.fn.statuscolumn.ISign
    local sign = {
      name = name,
      type = is_git_sign(name) and "git" or "sign",
      text = extmark[4].sign_text,
      texthl = extmark[4].sign_hl_group,
      priority = extmark[4].priority or 0,
    }

    signs_map[lnum] = signs_map[lnum] or {} ---@type fml.fn.statuscolumn.ISign[]
    table.insert(signs_map[lnum], sign)
  end

  -- Add marks
  local marks = vim.fn.getmarklist(bufnr)
  vim.list_extend(marks, vim.fn.getmarklist())
  for _, mark in ipairs(marks) do
    if mark.pos[1] == bufnr and mark.mark:match("[a-zA-Z]") then
      local lnum = mark.pos[2]

      ---@type fml.fn.statuscolumn.ISign
      local sign = {
        type = "mark",
        text = mark.mark:sub(2),
        texthl = "DiagnosticSignHint",
        priority = 0,
      }

      signs_map[lnum] = signs_map[lnum] or {} ---@type fml.fn.statuscolumn.ISign[]
      table.insert(signs_map[lnum], sign)
    end
  end

  cache[bufnr] = signs_map
  return signs_map
end

-- Returns a list of regular and extmark signs sorted by priority (high to low)
---@param winnr                         integer
---@param bufnr                         integer
---@param lnum                          integer
---@return fml.fn.statuscolumn.ISign[]
local function line_signs(winnr, bufnr, lnum)
  local signs = buf_signs(bufnr)[lnum] or {} ---@type fml.fn.statuscolumn.ISign[]

  -- Get fold signs
  vim.api.nvim_win_call(winnr, function()
    if vim.fn.foldclosed(vim.v.lnum) >= 0 then
      ---@type fml.fn.statuscolumn.ISign
      local sign = {
        type = "fold",
        text = eve.icons.fillchars.foldclose,
        texthl = "Folded",
        priority = 0,
      }
      table.insert(signs, sign)
    elseif config.folds.open and tostring(vim.treesitter.foldexpr(vim.v.lnum)):sub(1, 1) == ">" then
      ---@type fml.fn.statuscolumn.ISign
      local sign = {
        type = "fold",
        text = eve.icons.fillchars.foldopen,
        priority = 0,
      }
      table.insert(signs, sign)
    end
  end)

  -- Sort by priority
  table.sort(signs, function(a, b)
    return a.priority > b.priority
  end)
  return signs
end

---@param sign                          ?fml.fn.statuscolumn.ISign
---@param len                           ?integer
---@return string
local function get_icon(sign, len)
  sign = sign or {}
  len = len or 2
  local text = vim.fn.strcharpart(sign.text or "", 0, len) ---@type string
  text = text .. string.rep(" ", len - vim.fn.strchars(text))
  return sign.texthl and ("%#" .. sign.texthl .. "#" .. text .. "%*") or text
end

---@return string
local function statuscolumn()
  setup()

  local win = vim.g.statusline_winid
  local buf = vim.api.nvim_win_get_buf(win)
  local is_file = vim.bo[buf].buftype == ""
  local show_signs = vim.wo[win].signcolumn ~= "no"

  local components = { "", "", "" } -- left, middle, right

  if show_signs then
    local signs = line_signs(win, buf, vim.v.lnum)

    local left = find_sign(signs, config.left)
    local right = find_sign(signs, config.right)

    if config.folds.git_hl then
      local git = find_sign(signs, { "git" })
      if git and left and left.type == "fold" then
        left.texthl = git.texthl
      end
      if git and right and right.type == "fold" then
        right.texthl = git.texthl
      end
    end

    components[1] = get_icon(left) -- left
    components[3] = is_file and get_icon(right) or "" -- right
  end

  -- Numbers in Neovim are weird
  -- They show when either number or relativenumber is true
  local is_num = vim.wo[win].number
  local is_relnum = vim.wo[win].relativenumber
  if (is_num or is_relnum) and vim.v.virtnum == 0 then
    if vim.fn.has("nvim-0.11") == 1 then
      components[2] = "%l" -- 0.11 handles both the current and other lines with %l
    else
      if vim.v.relnum == 0 then
        components[2] = is_num and "%l" or "%r" -- the current line
      else
        components[2] = is_relnum and "%r" or "%l" -- other lines
      end
    end
    components[2] = "%=" .. components[2] .. " " -- right align
  end

  if vim.v.virtnum ~= 0 then
    components[2] = "%= "
  end

  return table.concat(components, "")
end

---@return string
local function safe_statuscolumn()
  local ok, result = pcall(statuscolumn)
  return ok and result or ""
end

return safe_statuscolumn
