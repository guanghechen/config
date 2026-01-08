local __module_name__ = "era.m.acp.widget" ---@type string

local S = era.m.acp

local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

---@class era.m.acp.widget.IProps
---@field public session                era.m.acp.Session

---@class era.m.acp.Widget : dot.t.IWidget
---@field public uuid                   string
---@field public fullname               string
---@field public session                era.m.acp.Session
---@field public input                  era.m.acp.Input
---@field public output                 era.m.acp.Output
---@field public sidebar                era.m.acp.Sidebar
---@field protected _disposed           boolean
---@field protected _visible            boolean
---@field protected _sidebar_visible    boolean
---@field protected _tabnr              ?integer
---@field protected _prev_tabnr         ?integer
---@field protected _cancel_request     ?fun(): nil
---@field protected _current_tool_id    ?string
---@field protected _assistant_text     string
---@field protected _spinner_timer      ?uv.uv_timer_t
---@field protected _spinner_idx        integer
---@field protected _generating_sub     ?stl.c.IUnsubscribable
---@field protected _base_title         string
---@field protected _agent_label        string
---@field protected _banner_shown       boolean
---@field protected _autocmd_group      ?integer
---@field private __send_message__      fun(self: era.m.acp.Widget, content: string, attachments: era.m.acp.IContentBlock[]): nil
local M = {}
M.__index = M

local INPUT_HEIGHT = 8
local SIDEBAR_WIDTH = 40

local PROVIDER_ICONS = {
  claude = "󰋦",
  codex = "󰧑",
  gemini = "󰊭",
  opencode = "󰘦",
}

---@param props                         era.m.acp.widget.IProps
---@return era.m.acp.Widget
function M.new(props)
  local self = setmetatable({}, M)
  self.uuid = yoz.fn.uuid()
  self.fullname = __module_name__
  self.session = props.session
  self._disposed = false
  self._visible = false
  self._sidebar_visible = true
  self._tabnr = nil
  self._prev_tabnr = nil
  self._cancel_request = nil
  self._current_tool_id = nil
  self._assistant_text = ""
  self._spinner_timer = nil
  self._spinner_idx = 1
  self._generating_sub = nil
  self._base_title = ""
  self._agent_label = ""
  self._banner_shown = false
  self._autocmd_group = nil

  self.output = S.output.new({
    session = props.session,
  })

  self.input = S.input.new({
    session = props.session,
    on_submit = function(content, attachments)
      M.__send_message__(self, content, attachments)
    end,
  })

  self.sidebar = S.sidebar.new({
    session = props.session,
  })

  return self
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isvisible()
  return self._visible and not self._disposed
end

---@return boolean
function M:isfocused()
  if not self._visible or self._disposed then
    return false
  end
  local current_win = vim.api.nvim_get_current_win()
  return current_win == self.input:winnr()
    or current_win == self.output:winnr()
    or current_win == self.sidebar:winnr()
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  if self._cancel_request then
    self._cancel_request()
    self._cancel_request = nil
  end

  self:__stop_spinner__()
  if self._generating_sub then
    self._generating_sub:unsubscribe()
    self._generating_sub = nil
  end

  if self._autocmd_group then
    vim.api.nvim_del_augroup_by_id(self._autocmd_group)
    self._autocmd_group = nil
  end

  self.session:dispose()
  self.input:dispose()
  self.output:dispose()
  self.sidebar:dispose()

  if self._tabnr and vim.api.nvim_tabpage_is_valid(self._tabnr) then
    local tabnr = self._tabnr ---@type integer
    self._tabnr = nil
    if self._prev_tabnr and vim.api.nvim_tabpage_is_valid(self._prev_tabnr) then
      vim.api.nvim_set_current_tabpage(self._prev_tabnr)
    end
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr)
    for _, winnr in ipairs(winnrs) do
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end
  end
end

---@return nil
function M:close()
  self:dispose()
end

---@return nil
function M:focus()
  if self._disposed then
    return
  end

  if self._tabnr and vim.api.nvim_tabpage_is_valid(self._tabnr) then
    vim.api.nvim_set_current_tabpage(self._tabnr)
    self.input:focus()
  else
    self:__create_tab__()
  end

  self._visible = true
  dot.state.widget.push(self)
end

---@return nil
function M:hide()
  if self._disposed then
    return
  end

  self._visible = false

  if self._prev_tabnr and vim.api.nvim_tabpage_is_valid(self._prev_tabnr) then
    vim.api.nvim_set_current_tabpage(self._prev_tabnr)
  end
end

---@return nil
function M:resize()
  if not self._visible or self._disposed then
    return
  end
  self:__resize_windows__()
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__create_tab__()
  -- Check if windows already exist and are valid
  local output_winnr = self.output:winnr()
  local input_winnr = self.input:winnr()
  local sidebar_winnr = self.sidebar:winnr()

  if output_winnr and vim.api.nvim_win_is_valid(output_winnr)
    and input_winnr and vim.api.nvim_win_is_valid(input_winnr)
    and sidebar_winnr and vim.api.nvim_win_is_valid(sidebar_winnr)
  then
    -- All windows exist, just focus
    vim.api.nvim_set_current_win(input_winnr)
    return
  end

  self._prev_tabnr = vim.api.nvim_get_current_tabpage()

  vim.cmd("tabnew")
  self._tabnr = vim.api.nvim_get_current_tabpage()

  output_winnr = vim.api.nvim_get_current_win()

  -- Create input window below output (before creating sidebar to avoid input spanning across sidebar)
  vim.cmd(string.format("belowright %dsplit", INPUT_HEIGHT))
  input_winnr = vim.api.nvim_get_current_win()

  -- Focus back to output window and create sidebar on the right of output
  vim.api.nvim_set_current_win(output_winnr)
  vim.cmd(string.format("rightbelow vertical %dsplit", SIDEBAR_WIDTH))
  sidebar_winnr = vim.api.nvim_get_current_win()

  -- Focus back to output window
  vim.api.nvim_set_current_win(output_winnr)

  -- Setup output window
  self.output:create_buf()
  local output_bufnr = self.output:bufnr()
  if output_bufnr then
    vim.api.nvim_win_set_buf(output_winnr, output_bufnr)
  end
  self.output:set_winnr(output_winnr)

  -- Setup sidebar window
  self.sidebar:create_buf()
  local sidebar_bufnr = self.sidebar:bufnr()
  if sidebar_bufnr then
    vim.api.nvim_win_set_buf(sidebar_winnr, sidebar_bufnr)
  end
  self.sidebar:set_winnr(sidebar_winnr)

  self.input:create_buf()
  local input_bufnr = self.input:bufnr()
  if input_bufnr then
    vim.api.nvim_win_set_buf(input_winnr, input_bufnr)
  end
  self.input:set_winnr(input_winnr)

  local provider_icon = PROVIDER_ICONS[self.session.provider] or "󰚩"
  local config = S.config.provider_configs[self.session.provider]
  self._agent_label = config and config.label or self.session.provider:gsub("^%l", string.upper)
  self._base_title = string.format("%s %s", provider_icon, self._agent_label)

  self:__setup_output_win__(output_winnr)
  self:__setup_input_win__(input_winnr)
  self:__setup_sidebar_win__(sidebar_winnr)
  self:__setup_winbar_autocmds__()
  self:__update_winbars__()

  self:__setup_widget_keymaps__()
  self:__setup_generating_subscription__()
  self:__show_banner_once__()

  self.sidebar:subscribe_to_changes()
  self.sidebar:refresh()

  self.input:focus()
end

---@protected
---@param winnr                        integer
---@return nil
function M:__setup_output_win__(winnr)
  vim.wo[winnr].wrap = true
  vim.wo[winnr].linebreak = true
  vim.wo[winnr].number = true
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].statuscolumn = "%l "
  vim.wo[winnr].cursorline = false
  vim.wo[winnr].foldcolumn = "0"
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winfixheight = false
  vim.wo[winnr].winbar = ""
  vim.wo[winnr].winhighlight = "Normal:f_acp_normal"
end

---@protected
---@param winnr                        integer
---@return nil
function M:__setup_input_win__(winnr)
  vim.wo[winnr].wrap = true
  vim.wo[winnr].linebreak = true
  vim.wo[winnr].number = true
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].statuscolumn = "%l "
  vim.wo[winnr].cursorline = false
  vim.wo[winnr].foldcolumn = "0"
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winfixheight = true
  vim.wo[winnr].winhighlight = "Normal:f_acp_input_normal"
end

---@protected
---@param winnr                        integer
---@return nil
function M:__setup_sidebar_win__(winnr)
  vim.wo[winnr].wrap = true
  vim.wo[winnr].linebreak = true
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].cursorline = true
  vim.wo[winnr].foldcolumn = "0"
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winfixwidth = true
  vim.wo[winnr].winbar = ""
  vim.wo[winnr].winhighlight = "Normal:f_acp_normal"
end

---@protected
---@param winnr                         integer|nil
---@param focused                       boolean
---@return nil
function M:__update_input_winbar__(winnr, focused)
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local sep_l = stl.icon.symbols.sep_left
  local sep_r = stl.icon.symbols.sep_right
  local title = self._base_title

  local hl_title = focused and "mf_b_bg0" or "f_acp_input_title"
  local hl_sep = focused and "ms_bg0" or "f_acp_input_title_sep"

  local winbar = "%="
    .. "%#" .. hl_sep .. "#" .. sep_l
    .. "%#" .. hl_title .. "#" .. title
    .. "%#" .. hl_sep .. "#" .. sep_r
    .. "%="
  vim.wo[winnr].winbar = winbar
end

---@protected
---@return nil
function M:__update_winbars__()
  local current_win = vim.api.nvim_get_current_win()
  local input_winnr = self.input:winnr()
  local input_focused = current_win == input_winnr
  self:__update_input_winbar__(input_winnr, input_focused)
end

---@protected
---@return nil
function M:__setup_winbar_autocmds__()
  if self._autocmd_group then
    return
  end

  self._autocmd_group = vim.api.nvim_create_augroup("acp_widget_" .. self.uuid, { clear = true })

  local input_bufnr = self.input:bufnr()

  if input_bufnr then
    vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "ModeChanged" }, {
      group = self._autocmd_group,
      buffer = input_bufnr,
      callback = function()
        if not self._disposed then
          self:__update_winbars__()
        end
      end,
    })
  end
end

---@protected
---@return nil
function M:__resize_windows__()
  local input_winnr = self.input:winnr()
  if input_winnr and vim.api.nvim_win_is_valid(input_winnr) then
    vim.api.nvim_win_set_height(input_winnr, INPUT_HEIGHT)
  end
end

---@protected
---@return nil
function M:__setup_widget_keymaps__()
  local keymaps = dot.state.widget.get_keymaps(self)

  local function setup_buf_keymaps(bufnr)
    if not bufnr then
      return
    end

    for _, km in ipairs(keymaps) do
      local opts = { buffer = bufnr, noremap = true, silent = true, desc = km.desc }
      vim.keymap.set(km.modes, km.key, km.callback, opts)
      if km.aliases then
        for _, alias in ipairs(km.aliases) do
          vim.keymap.set(km.modes, alias, km.callback, opts)
        end
      end
    end

    local win_opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set({ "n" }, "<C-j>", function()
      local input_winnr = self.input:winnr()
      if input_winnr and vim.api.nvim_win_is_valid(input_winnr) then
        vim.api.nvim_set_current_win(input_winnr)
      end
    end, vim.tbl_extend("force", win_opts, { desc = "acp: focus input" }))
    vim.keymap.set({ "n" }, "<C-k>", function()
      local output_winnr = self.output:winnr()
      if output_winnr and vim.api.nvim_win_is_valid(output_winnr) then
        vim.api.nvim_set_current_win(output_winnr)
      end
    end, vim.tbl_extend("force", win_opts, { desc = "acp: focus output" }))
    vim.keymap.set({ "n" }, "<C-p>", function()
      self.sidebar:toggle()
    end, vim.tbl_extend("force", win_opts, { desc = "acp: toggle sidebar" }))
  end

  setup_buf_keymaps(self.input:bufnr())

  -- Output buffer keymaps with diff support
  local output_bufnr = self.output:bufnr()
  if output_bufnr then
    setup_buf_keymaps(output_bufnr)

    -- Add diff viewing keymap for output buffer
    vim.keymap.set("n", "<CR>", function()
      self:__view_diff_at_cursor__()
    end, { buffer = output_bufnr, noremap = true, silent = true, desc = "acp: view diff" })

    vim.keymap.set("n", "gd", function()
      self:__view_diff_at_cursor__()
    end, { buffer = output_bufnr, noremap = true, silent = true, desc = "acp: view diff" })

    -- Add tool expand/collapse keymaps
    vim.keymap.set("n", "e", function()
      self:__toggle_tool_at_cursor__()
    end, { buffer = output_bufnr, noremap = true, silent = true, desc = "acp: toggle tool expand/collapse" })

    vim.keymap.set("n", "E", function()
      self:__toggle_all_tools__()
    end, { buffer = output_bufnr, noremap = true, silent = true, desc = "acp: toggle all tools expand/collapse" })
  end
end

---@protected
---@param content                       string
---@param attachments                   era.m.acp.IContentBlock[]
---@return nil
function M:__send_message__(content, attachments)
  local session = self.session

  -- Build content blocks or use plain string
  local msg_content ---@type string|era.m.acp.IContentBlock[]
  if #attachments > 0 then
    local content_blocks = {} ---@type era.m.acp.IContentBlock[]
    if content ~= "" then
      ---@type era.m.acp.ITextContent
      content_blocks[1] = {
        type = "text",
        text = content,
      }
    end
    for _, attachment in ipairs(attachments) do
      content_blocks[#content_blocks + 1] = attachment
    end
    msg_content = content_blocks
  else
    msg_content = content
  end

  local user_msg = session:add_user_message(msg_content)
  self.output:append_message(user_msg)

  session:reset_abort()
  session.generating:next(true)

  self._assistant_text = ""
  self._current_tool_id = nil

  self.output:append_assistant_header(self._agent_label)

  self._cancel_request = S.provider.send(session.provider, {
    session = session,
    cwd = session.cwd,
    messages = session.messages,
    abort = session.abort,
    on_chunk = function(chunk)
      self:__handle_chunk__(chunk)
    end,
    on_done = function()
      self:__handle_done__()
    end,
    on_error = function(err)
      self:__handle_error__(err)
    end,
  })
end

---@protected
---@param chunk                         era.m.acp.IStreamChunk
---@return nil
function M:__handle_chunk__(chunk)
  local session = self.session

  if chunk.type == "text" then
    self._assistant_text = self._assistant_text .. (chunk.content or "")
    self.output:append_text(chunk.content or "")
  elseif chunk.type == "thinking" then
    self.output:append_thinking(chunk.content or "")
  elseif chunk.type == "tool_use_start" then
    self._current_tool_id = chunk.tool_call_id
    session:start_tool_call(chunk.tool_call_id, chunk.tool_name or "")
  elseif chunk.type == "tool_use_delta" then
    if self._current_tool_id then
      session:append_tool_arguments(self._current_tool_id, chunk.tool_arguments_delta or "")
    end
  elseif chunk.type == "tool_use_end" then
    if self._current_tool_id then
      local tool_call = session:finish_tool_call(self._current_tool_id)
      if tool_call then
        self.output:append_tool_call(tool_call)
      end
    end
    self._current_tool_id = nil
  elseif chunk.type == "error" then
    self:__handle_error__(chunk.error or "Unknown error")
  end
end

---@protected
---@return nil
function M:__handle_done__()
  local session = self.session

  session:add_assistant_message(self._assistant_text)

  -- Stop spinner synchronously first, then update observable
  -- (Observable notification is async via vim.schedule)
  self:__stop_spinner__()
  session.generating:next(false)

  self._cancel_request = nil
  self.output:clear_assistant_header_line()
end

---@protected
---@param err                           string
---@return nil
function M:__handle_error__(err)
  -- Stop spinner synchronously first, then update observable
  -- (Observable notification is async via vim.schedule)
  self:__stop_spinner__()
  self.session.generating:next(false)

  self._cancel_request = nil
  self.output:clear_assistant_header_line()
  self.output:append_error(err)
end

---@protected
---@return nil
function M:__setup_generating_subscription__()
  if self._generating_sub then
    return
  end

  self._generating_sub = self.session.generating:subscribe(stl.c.Subscriber.new({
    on_next = function(generating)
      if generating then
        self:__start_spinner__()
      else
        self:__stop_spinner__()
      end
    end,
  }), true)
end

---@protected
---@return nil
function M:__start_spinner__()
  if self._spinner_timer then
    return
  end

  self._spinner_idx = 1
  self._spinner_timer = vim.uv.new_timer()
  self._spinner_timer:start(0, 80, vim.schedule_wrap(function()
    self._spinner_idx = (self._spinner_idx % #SPINNER_FRAMES) + 1
    self.output:update_assistant_spinner(SPINNER_FRAMES[self._spinner_idx])
  end))
end

---@protected
---@return nil
function M:__stop_spinner__()
  if self._spinner_timer then
    self._spinner_timer:stop()
    self._spinner_timer:close()
    self._spinner_timer = nil
  end
  self.output:update_assistant_spinner(nil)
end

---@protected
---@return nil
function M:__show_banner_once__()
  if self._banner_shown then
    return
  end
  self._banner_shown = true

  local config = S.config.provider_configs[self.session.provider]
  if config then
    self.output:show_banner(config, self.session.cwd)
  end
end

---@protected
---@return nil
function M:__view_diff_at_cursor__()
  local output_winnr = self.output:winnr()
  if not output_winnr or not vim.api.nvim_win_is_valid(output_winnr) then
    return
  end

  local bufnr = self.output:bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(output_winnr)
  local line_idx = cursor[1] - 1
  local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]

  if not line then
    return
  end

  -- Check if cursor is on [View Diff] button
  if not line:match("%[View Diff%]") then
    return
  end

  -- Find the tool call ID by searching backwards for tool border
  local tool_call_id = self:__find_tool_call_at_line__(bufnr, line_idx)
  if not tool_call_id then
    return
  end

  local diff_info = self.output:get_diff_info(tool_call_id)
  if not diff_info then
    return
  end

  -- Show diff
  local diff = era.m.acp.diff.new()
  diff:show({
    old_text = diff_info.old_text,
    new_text = diff_info.new_text,
    filepath = diff_info.filepath,
    title = string.format("Diff: %s", diff_info.filepath),
  })
end

---@protected
---@param bufnr                         integer
---@param start_line                    integer
---@return string|nil
function M:__find_tool_call_at_line__(bufnr, start_line)
  -- Search backwards to find tool border top (╭)
  for i = start_line, 0, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    if line and line:match("^%s*╭") then
      -- Found tool border, now find the tool name in header
      local header_line = vim.api.nvim_buf_get_lines(bufnr, i + 1, i + 2, false)[1]
      if header_line then
        -- Extract tool name (after icon and before padding)
        local tool_name = header_line:match("│%s*%S+%s+(%S+)")
        if tool_name then
          -- Find matching tool call in session
          for _, msg in ipairs(self.session.messages) do
            if msg.tool_calls then
              for _, tc in ipairs(msg.tool_calls) do
                if tc.name == tool_name then
                  return tc.id
                end
              end
            end
          end
        end
      end
      break
    end
  end
  return nil
end

---@protected
---@return nil
function M:__toggle_tool_at_cursor__()
  local output_winnr = self.output:winnr()
  if not output_winnr or not vim.api.nvim_win_is_valid(output_winnr) then
    return
  end

  local bufnr = self.output:bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(output_winnr)
  local line_idx = cursor[1] - 1

  local tool_id = self:__find_tool_at_line__(line_idx)
  if not tool_id then
    return
  end

  -- Toggle the expanded state
  self.session:toggle_tool_expanded(tool_id)
  local is_expanded = self.session:is_tool_expanded(tool_id)

  -- Update the display
  self.output:update_tool_expanded(tool_id, is_expanded)
end

---@protected
---@return nil
function M:__toggle_all_tools__()
  local bufnr = self.output:bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Determine if we should expand or collapse all
  -- If any tool is collapsed, expand all; otherwise collapse all
  local should_expand = false
  for _, msg in ipairs(self.session.messages) do
    if msg.tool_calls then
      for _, tc in ipairs(msg.tool_calls) do
        if not self.session:is_tool_expanded(tc.id) then
          should_expand = true
          break
        end
      end
    end
    if should_expand then
      break
    end
  end

  -- Toggle all tools
  for _, msg in ipairs(self.session.messages) do
    if msg.tool_calls then
      for _, tc in ipairs(msg.tool_calls) do
        local current_expanded = self.session:is_tool_expanded(tc.id)
        if current_expanded ~= should_expand then
          self.session:toggle_tool_expanded(tc.id)
          self.output:update_tool_expanded(tc.id, should_expand)
        end
      end
    end
  end
end

---@protected
---@param line                           integer
---@return string|nil
function M:__find_tool_at_line__(line)
  local bufnr = self.output:bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  -- Check all tool line ranges to find which tool this line belongs to
  for tool_id, range in pairs(self.output:get_tool_line_ranges()) do
    if line >= range.start and line <= range["end"] then
      return tool_id
    end
  end

  return nil
end

return M
