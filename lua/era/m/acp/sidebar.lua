---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.sidebar" ---@type string

local SIDEBAR_WIDTH = 40

local STATUS_ICONS = {
  pending = "○",
  in_progress = "◐",
  completed = "●",
}

local PRIORITY_ICONS = {
  high = "󰈸",
  medium = "󰈶",
  low = "󰈵",
}

---@class era.m.acp.sidebar.ISidebarOpts
---@field public session                era.m.acp.Session

---@class era.m.acp.Sidebar
---@field public session                era.m.acp.Session
---@field protected _bufnr              ?integer
---@field protected _winnr              ?integer
---@field protected _ns                 integer
---@field protected _visible            boolean
---@field protected _plan_sub           ?stl.c.IUnsubscribable
---@field protected _context_sub        ?stl.c.IUnsubscribable
---@field protected _plan_expanded      boolean
---@field protected _context_expanded   boolean
local M = {}
M.__index = M

---@param opts                          era.m.acp.sidebar.ISidebarOpts
---@return era.m.acp.Sidebar
function M.new(opts)
  local self = setmetatable({}, M)
  self.session = opts.session
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("acp_sidebar")
  self._visible = true
  self._plan_sub = nil
  self._context_sub = nil
  self._plan_expanded = true
  self._context_expanded = true
  return self
end

---@return integer|nil
function M:bufnr()
  return self._bufnr
end

---@return integer|nil
function M:winnr()
  return self._winnr
end

---@param winnr                         integer
---@return nil
function M:set_winnr(winnr)
  if self._winnr and self._winnr ~= winnr and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end
  self._winnr = winnr
end

---@return nil
function M:create_buf()
  if self._bufnr and vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end

  self._bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = self._bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self._bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = self._bufnr })
  vim.api.nvim_set_option_value("filetype", "acp-sidebar", { buf = self._bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = self._bufnr })

  self:__setup_keymaps__()
end

---@return nil
function M:dispose()
  if self._plan_sub then
    self._plan_sub:unsubscribe()
    self._plan_sub = nil
  end

  if self._context_sub then
    self._context_sub:unsubscribe()
    self._context_sub = nil
  end

  if self._bufnr and vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
    self._bufnr = nil
  end

  self._winnr = nil
end

---@return nil
function M:show()
  self._visible = true
  if self._winnr and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_set_config(self._winnr, {
      width = SIDEBAR_WIDTH,
    })
  end
  self:refresh()
end

---@return nil
function M:hide()
  self._visible = false
  if self._winnr and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_set_config(self._winnr, {
      width = 0,
    })
  end
end

---@return nil
function M:toggle()
  if self._visible then
    self:hide()
  else
    self:show()
  end
end

---@return nil
function M:refresh()
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end

  local render = era.m.acp.render
  local plan = self.session.plan and self.session.plan:snapshot() or nil ---@type era.m.acp.IPlan|nil
  local context_files = self.session.context_files and self.session.context_files:snapshot() or {}

  local lines = {} ---@type string[]
  local highlights = {} ---@type table<integer, { hl: string, col_start: integer, col_end: integer }[]>

  -- Plan section header
  local plan_icon = self._plan_expanded and render.icon_collapse or render.icon_expand
  local plan_header = plan_icon .. " Plan"
  lines[#lines + 1] = plan_header
  highlights[#lines] = {
    { hl = "f_acp_section_icon", col_start = 0, col_end = #plan_icon },
    { hl = "f_acp_section_title", col_start = #plan_icon + 1, col_end = #plan_header },
  }

  -- Plan separator
  lines[#lines + 1] = render.build_separator(SIDEBAR_WIDTH - 2, "solid")
  highlights[#lines] = { { hl = "f_acp_banner_sep", col_start = 0, col_end = #lines[#lines] } }

  if self._plan_expanded then
    if plan and plan.entries and #plan.entries > 0 then
      for _, entry in ipairs(plan.entries) do
        local status_icon = STATUS_ICONS[entry.status] or "○"
        local priority_icon = PRIORITY_ICONS[entry.priority] or ""
        local line = string.format("  %s %s %s", status_icon, entry.content, priority_icon)
        lines[#lines + 1] = line

        local status_hl = "f_acp_plan_" .. entry.status
        local priority_hl = "f_acp_plan_" .. entry.priority
        highlights[#lines] = {
          { hl = status_hl, col_start = 2, col_end = 2 + #status_icon },
          { hl = priority_hl, col_start = #line - #priority_icon, col_end = #line },
        }
      end
    else
      lines[#lines + 1] = "  No plan items"
      highlights[#lines] = { { hl = "f_acp_hint", col_start = 0, col_end = #lines[#lines] } }
    end
  end

  lines[#lines + 1] = ""

  -- Context section header
  local context_icon = self._context_expanded and render.icon_collapse or render.icon_expand
  local context_header = context_icon .. " Context"
  lines[#lines + 1] = context_header
  highlights[#lines] = {
    { hl = "f_acp_section_icon", col_start = 0, col_end = #context_icon },
    { hl = "f_acp_section_title", col_start = #context_icon + 1, col_end = #context_header },
  }

  -- Context separator
  lines[#lines + 1] = render.build_separator(SIDEBAR_WIDTH - 2, "solid")
  highlights[#lines] = { { hl = "f_acp_banner_sep", col_start = 0, col_end = #lines[#lines] } }

  if self._context_expanded then
    if #context_files > 0 then
      for _, file in ipairs(context_files) do
        local filename = vim.fn.fnamemodify(file.path, ":t")
        local line = string.format("  󰈔 %s", filename)
        lines[#lines + 1] = line
        highlights[#lines] = { { hl = "f_acp_context_file", col_start = 0, col_end = #line } }
      end
    else
      lines[#lines + 1] = "  No context files"
      highlights[#lines] = { { hl = "f_acp_hint", col_start = 0, col_end = #lines[#lines] } }
    end
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = self._bufnr })
  vim.api.nvim_buf_set_lines(self._bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = self._bufnr })

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(self._bufnr, self._ns, 0, -1)
  for line_idx, hls in pairs(highlights) do
    for _, hl in ipairs(hls) do
      vim.hl.range(self._bufnr, self._ns, hl.hl, { line_idx - 1, hl.col_start }, { line_idx - 1, hl.col_end })
    end
  end
end

---@return nil
function M:subscribe_to_changes()
  if self.session.plan then
    self._plan_sub = self.session.plan:subscribe(stl.c.Subscriber.new({
      on_next = function()
        self:refresh()
      end,
    }), true)
  end

  if self.session.context_files then
    self._context_sub = self.session.context_files:subscribe(stl.c.Subscriber.new({
      on_next = function()
        self:refresh()
      end,
    }), true)
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__setup_keymaps__()
  if not self._bufnr then
    return
  end

  local opts = { buffer = self._bufnr, noremap = true, silent = true }

  -- Toggle expand/collapse for current section
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local content = vim.api.nvim_buf_get_lines(self._bufnr, line - 1, line, false)[1]

    if content:match("^[󰅀󰅂]%s*Plan") then
      self._plan_expanded = not self._plan_expanded
      self:refresh()
    elseif content:match("^[󰅀󰅂]%s*Context") then
      self._context_expanded = not self._context_expanded
      self:refresh()
    end
  end, opts)

  -- Refresh
  vim.keymap.set("n", "r", function()
    self:refresh()
  end, vim.tbl_extend("force", opts, { desc = "acp sidebar: refresh" }))
end

return M
