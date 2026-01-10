---@class era.m.acp.confirm.IConfirmOpts
---@field public tool_call              table
---@field public options                table[]
---@field public callback               fun(option_id: string|nil): nil

---@class era.m.acp.confirm
local M = {}

local NS = vim.api.nvim_create_namespace("acp_confirm")

---Module-level state limits to one confirm dialog at a time.
---This is intentional for zen mode where only one ACP widget exists.
---@type { bufnr: integer|nil, winnr: integer|nil, callback: fun(option_id: string|nil)|nil, options: table[]|nil }
local _state = {
  bufnr = nil,
  winnr = nil,
  callback = nil,
  options = nil,
}

---@param opts                          era.m.acp.confirm.IConfirmOpts
---@return nil
function M.show(opts)
  if _state.winnr and vim.api.nvim_win_is_valid(_state.winnr) then
    M.close()
  end

  _state.callback = opts.callback
  _state.options = opts.options

  local tool_call = opts.tool_call
  local tool_name = tool_call.title or tool_call.toolCallId or "Unknown Tool"
  local tool_desc = ""

  if tool_call.rawInput then
    tool_desc = vim.inspect(tool_call.rawInput)
  end

  local lines = {} ---@type string[]
  local title_line_idx = 0
  lines[#lines + 1] = " Permission Required"
  local sep_line_idx_1 = #lines
  lines[#lines + 1] = string.rep("─", 60)
  lines[#lines + 1] = ""
  local tool_line_idx = #lines
  lines[#lines + 1] = "Tool: " .. tool_name
  if tool_desc ~= "" then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Input:"
    for _, line in ipairs(vim.split(tool_desc, "\n")) do
      lines[#lines + 1] = "  " .. line
    end
  end
  lines[#lines + 1] = ""
  local sep_line_idx_2 = #lines
  lines[#lines + 1] = string.rep("─", 60)
  lines[#lines + 1] = ""
  local action_line_idx = #lines
  lines[#lines + 1] = "Choose an action:"
  lines[#lines + 1] = ""

  local option_map = {} ---@type table<string, table>
  local option_line_indices = {} ---@type integer[]
  for _, option in ipairs(opts.options) do
    local key = ""
    if option.kind == "allow_once" then
      key = "y"
    elseif option.kind == "allow_always" then
      key = "a"
    elseif option.kind == "reject_once" then
      key = "n"
    elseif option.kind == "reject_always" then
      key = "r"
    end

    if key ~= "" then
      option_line_indices[#option_line_indices + 1] = #lines
      lines[#lines + 1] = string.format("  [%s] %s", key, option.name)
      option_map[key] = option
    end
  end

  lines[#lines + 1] = ""
  local hint_line_idx = #lines
  lines[#lines + 1] = "Press <Esc> to cancel"

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "acp_confirm", { buf = bufnr })

  local width = 70
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " ACP ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("winhighlight", "Normal:f_acp_normal,FloatBorder:f_acp_border,FloatTitle:f_acp_title", { win = winnr, scope = "local" })

  local title_line_len = #lines[title_line_idx + 1]
  vim.hl.range(bufnr, NS, "f_acp_banner_label", { title_line_idx, 0 }, { title_line_idx, title_line_len })
  local sep_line_1_len = #lines[sep_line_idx_1 + 1]
  vim.hl.range(bufnr, NS, "f_acp_banner_sep", { sep_line_idx_1, 0 }, { sep_line_idx_1, sep_line_1_len })
  vim.hl.range(bufnr, NS, "f_acp_tool_name", { tool_line_idx, 0 }, { tool_line_idx, 5 })
  local tool_line_len = #lines[tool_line_idx + 1]
  vim.hl.range(bufnr, NS, "f_acp_banner_value", { tool_line_idx, 6 }, { tool_line_idx, tool_line_len })
  local sep_line_2_len = #lines[sep_line_idx_2 + 1]
  vim.hl.range(bufnr, NS, "f_acp_banner_sep", { sep_line_idx_2, 0 }, { sep_line_idx_2, sep_line_2_len })
  local action_line_len = #lines[action_line_idx + 1]
  vim.hl.range(bufnr, NS, "f_acp_banner_label", { action_line_idx, 0 }, { action_line_idx, action_line_len })
  for _, idx in ipairs(option_line_indices) do
    vim.hl.range(bufnr, NS, "f_acp_tool_icon", { idx, 2 }, { idx, 5 })
  end
  local hint_line_len = #lines[hint_line_idx + 1]
  vim.hl.range(bufnr, NS, "f_acp_hint", { hint_line_idx, 0 }, { hint_line_idx, hint_line_len })

  _state.bufnr = bufnr
  _state.winnr = winnr

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    once = true,
    callback = function()
      M.close()
    end,
  })

  local function handle_key(key)
    local option = option_map[key]
    if option then
      M.__respond__(option.optionId)
    end
  end

  local keymaps = {
    { "n", "y", function() handle_key("y") end },
    { "n", "a", function() handle_key("a") end },
    { "n", "n", function() handle_key("n") end },
    { "n", "r", function() handle_key("r") end },
    { "n", "<Esc>", function() M.__respond__(nil) end },
    { "n", "q", function() M.__respond__(nil) end },
  }

  for _, map in ipairs(keymaps) do
    vim.keymap.set(map[1], map[2], map[3], {
      buffer = bufnr,
      nowait = true,
      silent = true,
    })
  end
end

---@return nil
function M.close()
  if _state.winnr and vim.api.nvim_win_is_valid(_state.winnr) then
    vim.api.nvim_win_close(_state.winnr, true)
  end
  if _state.bufnr and vim.api.nvim_buf_is_valid(_state.bufnr) then
    vim.api.nvim_buf_delete(_state.bufnr, { force = true })
  end
  _state.winnr = nil
  _state.bufnr = nil
end

----------------------------------------------------------------------------------------------------

---@protected
---@param option_id                     string|nil
---@return nil
function M.__respond__(option_id)
  if _state.callback then
    _state.callback(option_id)
    _state.callback = nil
  end
  _state.options = nil
  M.close()
end

return M
