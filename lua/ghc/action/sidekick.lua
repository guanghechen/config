---@class ghc.action.sidekick
local M = {}

local function read_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  return table.concat(lines, "\n")
end

function M.attach_agent()
  require("sidekick.cli").select({ filter = { installed = true } })
end

function M.detach_agent()
  require("sidekick.cli").close()
end

function M.submit_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local text = read_buffer(bufnr) ---@type string
  require("sidekick.cli").send({ text = { { { text } } }, render = false, focus = false, submit = true })
end

function M.submit_selection()
  local text = eve.buf.retrieve_selected_text() ---@type string
  require("sidekick.cli").send({ text = { { { text } } }, render = false, focus = false, submit = true })
end

function M.send_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local text = read_buffer(bufnr) ---@type string
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
