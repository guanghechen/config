---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.pairs.child" ---@type string

-- Runs typing cases in a child started with the ark runtime: `setup(variant, blink_root)` installs blink.pairs with
-- this configuration's options or era.keystroke.pairs, then `run(case)` types `case.keys` into a fresh buffer of
-- `case.filetype` and returns its lines and cursor, or the command line and its cursor for a command-line case.
-- blink.pairs reparses the whole buffer on each change here, so its balance checks follow full-parse semantics.

---@class __test__.fixtures.era.keystroke.pairs.ICase
---@field filetype                      string
---@field lines                         string[]
---@field cursor                        ?integer[] Zero-based row and byte column where typing starts.
---@field cmdline                       ?boolean Types on the command line instead.
---@field keys                          string

local M = {}

local variant = "era" ---@type string
local captured = nil ---@type table|nil

---@param name                          "blink"|"era"
---@param blink_root                    ?string
---@return nil
function M.setup(name, blink_root)
  variant = name
  vim.cmd("filetype plugin indent on")
  if name == "blink" then
    require("__test__.support.blink_pairs").setup(assert(blink_root))
  else
    era.keystroke.pairs.setup()
  end
  vim.keymap.set("i", "<F11>", function()
    local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
    captured = { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false), cursor = { cursor[1] - 1, cursor[2] } }
  end)
  vim.keymap.set("c", "<F12>", function()
    captured = { cmdline = vim.fn.getcmdline(), cursor = vim.fn.getcmdpos() - 1 }
  end)
end

---@param bufnr                         integer
---@return nil
local function blink_attach(bufnr)
  local rust = require("blink.pairs.rust")
  if not rust.supports_filetype(vim.bo[bufnr].filetype) then
    return
  end
  ---@return nil
  local function parse()
    local width = require("blink.pairs.utils").get_tab_width(bufnr)
    rust.parse_buffer(bufnr, width, vim.bo[bufnr].filetype, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end
  parse()
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      parse()
    end,
  })
end

---@param case                          __test__.fixtures.era.keystroke.pairs.ICase
---@return table
function M.run(case)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, case.lines)
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.bo[bufnr].filetype = case.filetype
  if pcall(vim.treesitter.start, bufnr) then
    vim.treesitter.get_parser(bufnr):parse(true)
  end
  if variant == "blink" then
    blink_attach(bufnr)
  end
  captured = nil
  if case.cmdline then
    vim.api.nvim_feedkeys(vim.keycode(":" .. case.keys .. "<F12><C-c>"), "tx", false)
  else
    local row, col = case.cursor[1], case.cursor[2]
    local line = case.lines[row + 1] ---@type string
    local start = "i" ---@type string
    if #line > 0 and col >= #line then
      col, start = #line - 1, "a"
    end
    vim.api.nvim_win_set_cursor(0, { row + 1, col })
    vim.api.nvim_feedkeys(vim.keycode(start .. case.keys .. "<F11><Esc>"), "tx", false)
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
  return assert(captured, "typing did not reach the capture key")
end

return M
