local __module_name__ = "ghc.action.sidekick" ---@type string

---@class ghc.action.sidekick
local M = {}

---@param subject                       string
---@return nil
local function notify_submit_success(subject)
  local ok_state, state = pcall(require, "sidekick.cli.state")
  if not ok_state then
    return
  end

  local ok_attached, attached = pcall(state.get, { attached = true })
  if not ok_attached or type(attached) ~= "table" then
    return
  end

  local names = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>
  for _, item in ipairs(attached) do
    if type(item) == "table" then
      local tool = item.tool ---@type table|nil
      local name = tool and tool.name or nil ---@type string|nil
      if type(name) == "string" and #name > 0 and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end

  if #names == 0 then
    return
  end

  table.sort(names)
  local label = table.concat(names, ", ") or "unknown agent" ---@type string

  std.reporter.info({
    from = __module_name__,
    subject = subject,
    message = string.format("Query send to %s succeed.", label),
  })
end

function M.attach_agent()
  require("sidekick.cli").select({ filter = { installed = true } })
end

function M.detach_agent()
  require("sidekick.cli").close()
end

---@return nil
function M.submit_buffer()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local text = eve.buf.retrieve_split_block(winnr) ---@type string

  local ok_cli, cli = pcall(require, "sidekick.cli")
  if not ok_cli then
    std.reporter.warn({
      from = __module_name__,
      subject = "submit_buffer",
      message = "Sidekick CLI is not available.",
    })
    return
  end

  local ok_send, err = pcall(cli.send, { text = { { { text } } }, render = false, focus = false, submit = true })
  if not ok_send then
    std.reporter.error({
      from = __module_name__,
      subject = "submit_buffer",
      message = "Failed to submit buffer to agent.",
      details = { error = err },
    })
    return
  end

  notify_submit_success("submit_buffer")
end

function M.submit_selection()
  local text = eve.buf.retrieve_selected_text() ---@type string
  local ok_cli, cli = pcall(require, "sidekick.cli")
  if not ok_cli then
    std.reporter.warn({
      from = __module_name__,
      subject = "submit_selection",
      message = "Sidekick CLI is not available.",
    })
    return
  end

  local ok_send, err = pcall(cli.send, { text = { { { text } } }, render = false, focus = false, submit = true })
  if not ok_send then
    std.reporter.error({
      from = __module_name__,
      subject = "submit_selection",
      message = "Failed to submit selection to agent.",
      details = { error = err },
    })
    return
  end

  notify_submit_success("submit_selection")
end

function M.send_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local text = table.concat(lines, "\n") ---@type string
  require("sidekick.cli").send({ text = { { { text } } }, render = false })
end

function M.send_selection()
  local text = eve.buf.retrieve_selected_text() ---@type string
  require("sidekick.cli").send({ text = { { { text } } }, render = false })
end

function M.send_this()
  require("sidekick.cli").send({ msg = "{this}" })
end

function M.send_file()
  require("sidekick.cli").send({ msg = "{file}" })
end

function M.select_prompt()
  require("sidekick.cli").prompt()
end

return M
