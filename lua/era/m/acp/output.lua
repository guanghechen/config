---@class era.m.acp.output.IOutputOpts
---@field public session                era.m.acp.Session

---@class era.m.acp.Output
---@field public session                era.m.acp.Session
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _ns                 integer
---@field protected _assistant_header_line integer|nil
---@field protected _assistant_label    string|nil
---@field protected _tool_diffs         table<string, { old_text: string, new_text: string, filepath: string }>
---@field protected _tool_line_ranges   table<string, { start: integer, end: integer }>
local M = {}
M.__index = M

---@param opts                          era.m.acp.output.IOutputOpts
---@return era.m.acp.Output
function M.new(opts)
  local self = setmetatable({}, M)
  self.session = opts.session
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("acp_output")
  self._assistant_header_line = nil
  self._assistant_label = nil
  self._tool_diffs = {}
  self._tool_line_ranges = {}
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

---@param winnr                        integer
---@return nil
function M:set_winnr(winnr)
  if self._winnr and self._winnr ~= winnr and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end
  self._winnr = winnr

  local bufnr = self._bufnr ---@type integer
  if vim.api.nvim_win_get_buf(winnr) ~= bufnr then
    return
  end

  vim.api.nvim_win_call(winnr, function()
    -- Trigger FileType autocmd only once per buffer
    if not vim.b[bufnr].acp_filetype_done then
      vim.b[bufnr].acp_filetype_done = true
      vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
    end

    -- Trigger render-markdown (safe to call multiple times)
    local ok, rm_api = pcall(require, "render-markdown.api")
    if ok then
      rm_api.render({ buf = bufnr, win = winnr })
    end
  end)
end

---@return nil
function M:create_buf()
  if self._bufnr ~= nil then
    return
  end

  self._bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = self._bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = self._bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = self._bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = self._bufnr })
  vim.api.nvim_set_option_value("filetype", stl.filetype.ACP_OUTPUT, { buf = self._bufnr })
  vim.treesitter.start(self._bufnr, "markdown")
end

---@return nil
function M:dispose()
  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end
  self._winnr = nil
  if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
  end
  self._bufnr = nil
end

---@param msg                           era.m.acp.IMessage
---@param agent_label                   ?string
---@return nil
function M:append_message(msg, agent_label)
  local header ---@type string
  if msg.role == "user" then
    header = "## 󰀄 You"
  else
    header = "## 󱚥 " .. (agent_label or "Assistant")
  end

  -- Handle content blocks or plain string
  if type(msg.content) == "table" then
    local content_blocks = msg.content --[[@as era.m.acp.IContentBlock[] ]]
    local lines = { header, "" }
    for _, block in ipairs(content_blocks) do
      if block.type == "text" then
        lines[#lines + 1] = block.text
      elseif block.type == "image" then
        self:__append_lines__(lines)
        lines = {}
        self:append_image(block)
      elseif block.type == "audio" then
        lines[#lines + 1] = string.format("[Audio: %s, %d bytes]", block.mime_type, #block.data)
      elseif block.type == "resource" then
        self:__append_lines__(lines)
        lines = {}
        self:append_resource(block)
      end
    end
    lines[#lines + 1] = ""
    self:__append_lines__(lines)
  else
    local content = header .. "\n\n" .. msg.content .. "\n\n"
    self:__append_lines__(vim.split(content, "\n", { plain = true }))
  end
end

---@param image_content                 era.m.acp.IImageContent
---@return nil
function M:append_image(image_content)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local data_len = #image_content.data
  local uri_info = image_content.uri and (" " .. image_content.uri) or ""
  local lines = {
    string.format("  🖼️  Image: %s%s", image_content.mime_type, uri_info),
    string.format("  Data: %d bytes (base64)", data_len),
    "",
  }

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  local start_line = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Highlight image info
  vim.hl.range(bufnr, self._ns, "f_acp_image", { start_line, 0 }, { start_line, #lines[1] })

  self:__scroll_to_bottom__()
end

---@param resource_content              era.m.acp.IResourceContent
---@return nil
function M:append_resource(resource_content)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local res = resource_content.resource
  local lines = {
    string.format("  🔗 Resource: %s", res.uri),
  }
  if res.text then
    lines[#lines + 1] = string.format("  Text: %s", res.text:sub(1, 100))
  end
  if res.mime_type then
    lines[#lines + 1] = string.format("  Type: %s", res.mime_type)
  end
  lines[#lines + 1] = ""

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  local start_line = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Highlight resource info
  vim.hl.range(bufnr, self._ns, "f_acp_resource", { start_line, 0 }, { start_line, #lines[1] })

  self:__scroll_to_bottom__()
end

---@param text                          string
---@return nil
function M:append_text(text)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local last_line = vim.api.nvim_buf_get_lines(bufnr, line_count - 1, line_count, false)[1] or ""

  local lines = vim.split(text, "\n", { plain = true })
  if #lines == 1 then
    vim.api.nvim_buf_set_text(bufnr, line_count - 1, #last_line, line_count - 1, #last_line, lines)
  else
    lines[1] = last_line .. lines[1]
    vim.api.nvim_buf_set_lines(bufnr, line_count - 1, line_count, false, lines)
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  self:__scroll_to_bottom__()
end

---@param text                          string
---@return nil
function M:append_thinking(text)
  -- For now, just append thinking as regular text
  -- Could be styled differently in the future
  self:append_text(text)
end

---@param tool_call                     era.m.acp.IToolCall
---@return nil
function M:append_tool_call(tool_call)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local is_expanded = self.session:is_tool_expanded(tool_call.id)
  local icon = self:__get_tool_icon__(tool_call.name)
  local args_preview = self:__format_tool_args__(tool_call.arguments, tool_call.name)

  -- Detect edit tools and extract diff info
  local has_diff = self:__extract_diff_info__(tool_call)

  local indent = "  "
  local indent_len = #indent

  if not is_expanded then
    -- Collapsed: single line display
    local header_text = string.format("%s %s", icon, tool_call.name)
    local args_text = args_preview[1] or ""

    local content = string.format("%s ─ %s", header_text, args_text)
    local max_width = vim.fn.strdisplaywidth(content)
    local padding = string.rep("─", math.max(2, 50 - max_width))

    local line = indent .. "╭─ " .. content .. " ─" .. padding .. "╮"

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    local start_line = vim.api.nvim_buf_line_count(bufnr)
    local is_empty = start_line == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""

    if is_empty then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", line })
      start_line = 1
    else
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", line })
      start_line = start_line + 1
    end
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    -- Store line range
    self._tool_line_ranges[tool_call.id] = { start = start_line, ["end"] = start_line }

    -- Highlight collapsed tool box
    local line_len = #line
    vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { start_line, 0 }, { start_line, line_len })

    -- Highlight icon and name
    local icon_start = indent_len + #"╭─ "
    local icon_end = icon_start + #icon
    local name_start = icon_end + 1
    local name_end = name_start + #tool_call.name
    vim.hl.range(bufnr, self._ns, "f_acp_tool_icon", { start_line, icon_start }, { start_line, icon_end })
    vim.hl.range(bufnr, self._ns, "f_acp_tool_name", { start_line, name_start }, { start_line, name_end })

    -- Add virtual text hint
    vim.api.nvim_buf_set_extmark(bufnr, self._ns, start_line, 0, {
      virt_text = { { " [e: Expand]", "f_acp_tool_hint" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  else
    -- Expanded: full display
    local header_text = string.format("%s %s", icon, tool_call.name)

    local max_width = vim.fn.strdisplaywidth(header_text)
    for _, line in ipairs(args_preview) do
      max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
    end

    -- Add "View Diff" button if has diff
    if has_diff then
      local diff_button = "󰒉 [View Diff]"
      max_width = math.max(max_width, vim.fn.strdisplaywidth(diff_button))
    end

    local top_line = indent .. "╭" .. string.rep("─", max_width + 2) .. "╮"
    local header_line = indent
      .. "│ "
      .. header_text
      .. string.rep(" ", max_width - vim.fn.strdisplaywidth(header_text))
      .. " │"
    local body_lines = {} ---@type string[]
    for _, line in ipairs(args_preview) do
      body_lines[#body_lines + 1] = indent
        .. "│ "
        .. line
        .. string.rep(" ", max_width - vim.fn.strdisplaywidth(line))
        .. " │"
    end

    -- Add diff button line
    if has_diff then
      local diff_button = "󰒉 [View Diff]"
      body_lines[#body_lines + 1] = indent
        .. "│ "
        .. diff_button
        .. string.rep(" ", max_width - vim.fn.strdisplaywidth(diff_button))
        .. " │"
    end

    local bottom_line = indent .. "╰" .. string.rep("─", max_width + 2) .. "╯"

    local lines = { "", top_line, header_line }
    for _, line in ipairs(body_lines) do
      lines[#lines + 1] = line
    end
    lines[#lines + 1] = bottom_line

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    local start_line = vim.api.nvim_buf_line_count(bufnr)
    local is_empty = start_line == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""

    if is_empty then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      start_line = 0
    else
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
    end
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    local top_idx = start_line + 1
    local header_idx = start_line + 2
    local footer_idx = start_line + (#lines - 1)

    -- Store line range
    self._tool_line_ranges[tool_call.id] = { start = top_idx, ["end"] = footer_idx }

    -- Highlight borders (top and bottom)
    local top_len = #lines[2]
    vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { top_idx, 0 }, { top_idx, top_len })
    local footer_len = #lines[#lines]
    vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { footer_idx, 0 }, { footer_idx, footer_len })

    -- Highlight side borders for header + body
    for i = 3, #lines - 1 do
      local line_idx = start_line + (i - 1)
      local line = lines[i]
      local left_end = vim.str_byteindex(line, "utf-8", 1)
      local right_start = vim.str_byteindex(line, "utf-8", vim.str_utfindex(line, "utf-8") - 1)
      vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { line_idx, 0 }, { line_idx, left_end })
      vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { line_idx, right_start }, { line_idx, #line })
    end

    -- Highlight icon and name within header
    local icon_start = #"│ "
    local icon_end = icon_start + #icon
    local name_start = icon_end + 1
    local name_end = name_start + #tool_call.name
    local header_len = #lines[3]

    local header_inner_start = indent_len + #"│ "
    local header_inner_end = header_len - #" │"

    vim.hl.range(
      bufnr,
      self._ns,
      "f_acp_tool_header",
      { header_idx, header_inner_start },
      { header_idx, header_inner_end }
    )
    vim.hl.range(
      bufnr,
      self._ns,
      "f_acp_tool_icon",
      { header_idx, indent_len + icon_start },
      { header_idx, indent_len + icon_end }
    )
    vim.hl.range(
      bufnr,
      self._ns,
      "f_acp_tool_name",
      { header_idx, indent_len + name_start },
      { header_idx, math.min(indent_len + name_end, header_len) }
    )

    -- Highlight diff button
    if has_diff then
      local diff_line_idx = start_line + #lines - 2
      local diff_button = "󰒉 [View Diff]"
      local diff_start = indent_len + #"│ "
      local diff_end = diff_start + #diff_button
      vim.hl.range(bufnr, self._ns, "f_acp_diff_button", { diff_line_idx, diff_start }, { diff_line_idx, diff_end })
    end

    -- Add virtual text hint
    vim.api.nvim_buf_set_extmark(bufnr, self._ns, top_idx, 0, {
      virt_text = { { " [e: Collapse]", "f_acp_tool_hint" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end

  self:__scroll_to_bottom__()
end

---@param tool_call_id                  string
---@param result                        string
---@param is_error                      boolean
---@return nil
function M:append_tool_result(tool_call_id, result, is_error)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local icon = is_error and "" or ""
  local label = is_error and "Error" or "Done"
  local hl = is_error and "f_acp_tool_error" or "f_acp_tool_success"

  -- Check if tool is expanded
  local is_expanded = self.session:is_tool_expanded(tool_call_id)
  local truncated = result

  if not is_expanded then
    -- Truncate result for collapsed view
    local result_lines = vim.split(result, "\n", { plain = true })
    if #result_lines > 3 then
      truncated = table.concat(vim.list_slice(result_lines, 1, 3), " ")
      truncated = truncated .. string.format(" ... (%d lines truncated)", #result_lines - 3)
    else
      truncated = result:gsub("\n", " ")
    end

    local max_len = 200
    if #truncated > max_len then
      truncated = truncated:sub(1, max_len) .. "..."
    end
    truncated = truncated:gsub("%s+", " ")
  else
    -- Show full result for expanded view
    local max_len = 500
    if #result > max_len then
      truncated = result:sub(1, max_len) .. "..."
    end
    truncated = truncated:gsub("\n", " "):gsub("%s+", " ")
  end

  local lines = {
    string.format("  %s %s: %s", icon, label, truncated),
    "",
  }

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  local start_line = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Highlight result line
  local result_line_len = #lines[1]
  vim.hl.range(bufnr, self._ns, hl, { start_line, 0 }, { start_line, result_line_len })

  self:__scroll_to_bottom__()
end

---@param agent_label                   string
---@return nil
function M:append_assistant_header(agent_label)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  self._assistant_label = agent_label
  local header = "## 󱚥 " .. agent_label
  local lines = { header, "", "" }

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local is_empty = line_count == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""

  if is_empty then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    self._assistant_header_line = 0
  else
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
    self._assistant_header_line = line_count
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  self:__scroll_to_bottom__()
end

---@param spinner_frame                 ?string
---@return nil
function M:update_assistant_spinner(spinner_frame)
  local bufnr = self._bufnr
  local header_line = self._assistant_header_line
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) or header_line == nil then
    return
  end

  local label = self._assistant_label or "Assistant"
  local header ---@type string
  if spinner_frame then
    header = "## 󱚥 " .. label .. " " .. spinner_frame
  else
    header = "## 󱚥 " .. label
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, header_line, header_line + 1, false, { header })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

---@return nil
function M:clear_assistant_header_line()
  self._assistant_header_line = nil
  self._assistant_label = nil
end

---@param err                           string
---@return nil
function M:append_error(err)
  local text = string.format("\n>  **Error**: %s\n\n", err)
  self:__append_lines__(vim.split(text, "\n", { plain = true }))
end

---@return nil
function M:clear()
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

---@param config                       era.m.acp.IProviderConfig
---@param cwd                          string
---@return nil
function M:show_banner(config, cwd)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local rows = {
    { key = "󰳐 Model", value = config.model },
    { key = "󰉋 Path", value = cwd },
  }

  local key_width = 0
  for _, row in ipairs(rows) do
    key_width = math.max(key_width, vim.fn.strdisplaywidth(row.key))
  end

  local lines = {
    "",
  }

  local label_line = string.format("  %s", config.label)
  lines[#lines + 1] = label_line
  lines[#lines + 1] = ""

  local max_line_width = vim.fn.strdisplaywidth(label_line)
  for _, row in ipairs(rows) do
    local padding = key_width - vim.fn.strdisplaywidth(row.key)
    local line = string.format("  %s%s  %s", row.key, string.rep(" ", padding), row.value)
    lines[#lines + 1] = line
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. string.rep("─", math.max(max_line_width - 2, 0))
  lines[#lines + 1] = ""

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Highlight label line (line 1, 0-indexed)
  local label_len = #lines[2]
  vim.hl.range(bufnr, self._ns, "f_acp_banner_label", { 1, 0 }, { 1, label_len })

  -- Highlight keys/values
  for idx, row in ipairs(rows) do
    local line_idx = 2 + idx
    local key_start = 2
    local key_end = key_start + #row.key
    local value_start = key_end + (key_width - vim.fn.strdisplaywidth(row.key)) + 2
    local line_len = #lines[line_idx + 1]
    vim.hl.range(bufnr, self._ns, "f_acp_banner_key", { line_idx, key_start }, { line_idx, key_end })
    vim.hl.range(bufnr, self._ns, "f_acp_banner_value", { line_idx, value_start }, { line_idx, line_len })
  end

  -- Highlight separator
  local sep_idx = #lines - 2
  local sep_len = #lines[sep_idx + 1]
  vim.hl.range(bufnr, self._ns, "f_acp_banner_sep", { sep_idx, 0 }, { sep_idx, sep_len })
end

---@param tool_call_id                  string
---@return { old_text: string, new_text: string, filepath: string }|nil
function M:get_diff_info(tool_call_id)
  return self._tool_diffs[tool_call_id]
end

---@return table<string, { start: integer, end: integer }>
function M:get_tool_line_ranges()
  return self._tool_line_ranges
end

----------------------------------------------------------------------------------------------------

---@protected
---@param lines                         string[]
---@return nil
function M:__append_lines__(lines)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local is_empty = line_count == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""

  if is_empty then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  self:__scroll_to_bottom__()
end

---@protected
---@return nil
function M:__scroll_to_bottom__()
  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
    local line_count = vim.api.nvim_buf_line_count(self._bufnr)
    vim.api.nvim_win_set_cursor(self._winnr, { line_count, 0 })
  end
end

local TOOL_ICON_RULES = {
  { "view", "" },
  { "read", "󰈙" },
  { "edit", "󰙏" },
  { "write", "󰙏" },
  { "create", "󰐖" },
  { "bash", "" },
  { "grep", "󰍉" },
  { "glob", "󰈞" },
  { "ls", "󰉋" },
  { "search", "󰍉" },
  { "replace", "󰛔" },
}

local TOOL_ICON_FALLBACK = "󰊕" ---@type string

---@protected
---@param name                         string
---@return string
function M:__get_tool_icon__(name)
  local lower = name:lower()
  for _, rule in ipairs(TOOL_ICON_RULES) do
    if lower:find(rule[1]) then
      return rule[2]
    end
  end
  return TOOL_ICON_FALLBACK
end

---@protected
---@param args                         table
---@param tool_name                    string
---@return string[]
function M:__format_tool_args__(args, tool_name)
  args = args or {}
  local lines = {} ---@type string[]
  local lower_name = tool_name:lower()

  -- Special formatting for common tools
  if lower_name:find("view") or lower_name:find("read") then
    if args.file_path or args.path then
      lines[#lines + 1] = args.file_path or args.path
    end
  elseif lower_name:find("edit") or lower_name:find("write") then
    if args.file_path or args.path then
      lines[#lines + 1] = args.file_path or args.path
    end
    if args.old_string then
      local preview = args.old_string:gsub("\n", "↵"):sub(1, 40)
      if #args.old_string > 40 then
        preview = preview .. "..."
      end
      lines[#lines + 1] = "old: " .. preview
    end
  elseif lower_name:find("bash") then
    if args.command then
      local cmd = args.command:gsub("\n", " "):sub(1, 50)
      if #args.command > 50 then
        cmd = cmd .. "..."
      end
      lines[#lines + 1] = string.format("$ %s", cmd)
    end
  elseif lower_name:find("grep") or lower_name:find("search") then
    if args.pattern then
      lines[#lines + 1] = string.format("󰑑 %s", args.pattern)
    end
    if args.path then
      lines[#lines + 1] = "path: " .. args.path
    end
  elseif lower_name:find("glob") then
    if args.pattern then
      lines[#lines + 1] = string.format("󰈞 %s", args.pattern)
    end
  elseif lower_name:find("create") then
    if args.file_path or args.path then
      lines[#lines + 1] = args.file_path or args.path
    end
  else
    -- Generic formatting: show key-value pairs
    for key, value in pairs(args) do
      local val_str = type(value) == "string" and value or vim.json.encode(value)
      val_str = val_str:gsub("\n", "↵"):sub(1, 40)
      if #tostring(value) > 40 then
        val_str = val_str .. "..."
      end
      lines[#lines + 1] = string.format("%s: %s", key, val_str)
      if #lines >= 3 then
        break
      end
    end
  end

  if #lines == 0 then
    lines[#lines + 1] = "(no arguments)"
  end

  return lines
end

---@protected
---@param tool_call                     era.m.acp.IToolCall
---@return boolean
function M:__extract_diff_info__(tool_call)
  local args = tool_call.arguments or {}
  local lower_name = tool_call.name:lower()

  -- Check if it's an edit tool
  local is_edit_tool = lower_name:find("edit") or lower_name:find("write") or lower_name:find("str_replace")

  if not is_edit_tool then
    return false
  end

  local filepath = args.file_path or args.path
  if not filepath then
    return false
  end

  -- For edit/str_replace tools
  if args.old_string and args.new_string then
    self._tool_diffs[tool_call.id] = {
      old_text = args.old_string,
      new_text = args.new_string,
      filepath = filepath,
    }
    return true
  end

  -- For write tools with content
  if args.content then
    -- Try to read old file content
    local old_text = ""
    local file = io.open(filepath, "r")
    if file then
      old_text = file:read("*all")
      file:close()
    end

    self._tool_diffs[tool_call.id] = {
      old_text = old_text,
      new_text = args.content,
      filepath = filepath,
    }
    return true
  end

  return false
end

---@param tool_id                       string
---@param expanded                      boolean
---@return nil
function M:update_tool_expanded(tool_id, expanded)
  local bufnr = self._bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Find the tool call
  local tool_call = nil ---@type era.m.acp.IToolCall|nil
  for _, msg in ipairs(self.session.messages) do
    if msg.tool_calls then
      for _, tc in ipairs(msg.tool_calls) do
        if tc.id == tool_id then
          tool_call = tc
          break
        end
      end
    end
    if tool_call then
      break
    end
  end

  if not tool_call then
    return
  end

  local line_range = self._tool_line_ranges[tool_id]
  if not line_range then
    return
  end

  -- Clear extmarks in the range
  local extmarks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    self._ns,
    { line_range.start, 0 },
    { line_range["end"], -1 },
    {}
  )
  for _, extmark in ipairs(extmarks) do
    vim.api.nvim_buf_del_extmark(bufnr, self._ns, extmark[1])
  end

  -- Delete old lines
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, line_range.start, line_range["end"] + 1, false, {})
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Re-render the tool call
  local icon = self:__get_tool_icon__(tool_call.name)
  local args_preview = self:__format_tool_args__(tool_call.arguments, tool_call.name)
  local has_diff = self._tool_diffs[tool_id] ~= nil

  local indent = "  "
  local indent_len = #indent

  if not expanded then
    -- Collapsed: single line display
    local header_text = string.format("%s %s", icon, tool_call.name)
    local args_text = args_preview[1] or ""

    local content = string.format("%s ─ %s", header_text, args_text)
    local max_width = vim.fn.strdisplaywidth(content)
    local padding = string.rep("─", math.max(2, 50 - max_width))

    local line = indent .. "╭─ " .. content .. " ─" .. padding .. "╮"

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, line_range.start, line_range.start, false, { line })
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    local start_line = line_range.start

    -- Update line range
    self._tool_line_ranges[tool_id] = { start = start_line, ["end"] = start_line }

    -- Highlight collapsed tool box
    local line_len = #line
    vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { start_line, 0 }, { start_line, line_len })

    -- Highlight icon and name
    local icon_start = indent_len + #"╭─ "
    local icon_end = icon_start + #icon
    local name_start = icon_end + 1
    local name_end = name_start + #tool_call.name
    vim.hl.range(bufnr, self._ns, "f_acp_tool_icon", { start_line, icon_start }, { start_line, icon_end })
    vim.hl.range(bufnr, self._ns, "f_acp_tool_name", { start_line, name_start }, { start_line, name_end })

    -- Add virtual text hint
    vim.api.nvim_buf_set_extmark(bufnr, self._ns, start_line, 0, {
      virt_text = { { " [e: Expand]", "f_acp_tool_hint" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  else
    -- Expanded: full display
    local header_text = string.format("%s %s", icon, tool_call.name)

    local max_width = vim.fn.strdisplaywidth(header_text)
    for _, line in ipairs(args_preview) do
      max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
    end

    if has_diff then
      local diff_button = "󰒉 [View Diff]"
      max_width = math.max(max_width, vim.fn.strdisplaywidth(diff_button))
    end

    local top_line = indent .. "╭" .. string.rep("─", max_width + 2) .. "╮"
    local header_line = indent
      .. "│ "
      .. header_text
      .. string.rep(" ", max_width - vim.fn.strdisplaywidth(header_text))
      .. " │"
    local body_lines = {} ---@type string[]
    for _, line in ipairs(args_preview) do
      body_lines[#body_lines + 1] = indent
        .. "│ "
        .. line
        .. string.rep(" ", max_width - vim.fn.strdisplaywidth(line))
        .. " │"
    end

    if has_diff then
      local diff_button = "󰒉 [View Diff]"
      body_lines[#body_lines + 1] = indent
        .. "│ "
        .. diff_button
        .. string.rep(" ", max_width - vim.fn.strdisplaywidth(diff_button))
        .. " │"
    end

    local bottom_line = indent .. "╰" .. string.rep("─", max_width + 2) .. "╯"

    local lines = { top_line, header_line }
    for _, line in ipairs(body_lines) do
      lines[#lines + 1] = line
    end
    lines[#lines + 1] = bottom_line

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, line_range.start, line_range.start, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    local start_line = line_range.start
    local top_idx = start_line
    local header_idx = start_line + 1
    local footer_idx = start_line + (#lines - 1)

    -- Update line range
    self._tool_line_ranges[tool_id] = { start = top_idx, ["end"] = footer_idx }

    -- Highlight borders
    local top_len = #lines[1]
    vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { top_idx, 0 }, { top_idx, top_len })
    local footer_len = #lines[#lines]
    vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { footer_idx, 0 }, { footer_idx, footer_len })

    -- Highlight side borders
    for i = 2, #lines - 1 do
      local line_idx = start_line + (i - 1)
      local line = lines[i]
      local left_end = vim.str_byteindex(line, "utf-8", 1)
      local right_start = vim.str_byteindex(line, "utf-8", vim.str_utfindex(line, "utf-8") - 1)
      vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { line_idx, 0 }, { line_idx, left_end })
      vim.hl.range(bufnr, self._ns, "f_acp_tool_border", { line_idx, right_start }, { line_idx, #line })
    end

    -- Highlight icon and name
    local icon_start = #"│ "
    local icon_end = icon_start + #icon
    local name_start = icon_end + 1
    local name_end = name_start + #tool_call.name
    local header_len = #lines[2]

    local header_inner_start = indent_len + #"│ "
    local header_inner_end = header_len - #" │"

    vim.hl.range(
      bufnr,
      self._ns,
      "f_acp_tool_header",
      { header_idx, header_inner_start },
      { header_idx, header_inner_end }
    )
    vim.hl.range(
      bufnr,
      self._ns,
      "f_acp_tool_icon",
      { header_idx, indent_len + icon_start },
      { header_idx, indent_len + icon_end }
    )
    vim.hl.range(
      bufnr,
      self._ns,
      "f_acp_tool_name",
      { header_idx, indent_len + name_start },
      { header_idx, math.min(indent_len + name_end, header_len) }
    )

    -- Highlight diff button
    if has_diff then
      local diff_line_idx = start_line + #lines - 2
      local diff_button = "󰒉 [View Diff]"
      local diff_start = indent_len + #"│ "
      local diff_end = diff_start + #diff_button
      vim.hl.range(bufnr, self._ns, "f_acp_diff_button", { diff_line_idx, diff_start }, { diff_line_idx, diff_end })
    end

    -- Add virtual text hint
    vim.api.nvim_buf_set_extmark(bufnr, self._ns, top_idx, 0, {
      virt_text = { { " [e: Collapse]", "f_acp_tool_hint" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end
end

return M
