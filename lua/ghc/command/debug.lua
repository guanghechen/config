local client = require("ghc.context.client")
local session = require("ghc.context.session")
local transient = require("ghc.context.transient")

---@class ghc.command.debug
local M = {}

function M.inspect()
  fc.reporter.info({
    from = "ghc.command.debug",
    subject = "inspect",
    details = {
      tabnr = vim.api.nvim_get_current_tabpage() or "nil",
      winnr = vim.api.nvim_get_current_win() or "nil",
      bufnr = vim.api.nvim_get_current_buf() or "nil",
      tabnrs = vim.api.nvim_list_tabpages(),
      bufnrs = vim.api.nvim_list_bufs(),
    },
  })
end

---@return nil
function M.show_context()
  local context = {
    config = client:snapshot(),
    session = session:snapshot(),
    transient = transient:snapshot(),
  }

  fc.reporter.info({
    from = "ghc.command.debug",
    subject = "show_context",
    details = context,
  })
end

---@return nil
function M.show_context_all()
  local context = {
    config = vim.tbl_deep_extend("force", { _location = ghc.context.client:get_filepath() }, client:snapshot_all()),
    session = vim.tbl_deep_extend("force", { _location = ghc.context.session:get_filepath() }, session:snapshot_all()),
    transient = vim.tbl_deep_extend("force", {}, transient:snapshot_all()),
  }

  fc.reporter.info({
    from = "ghc.command.debug",
    subject = "show_context_all",
    details = context,
  })
end

---@return nil
function M.show_editor_state()
  local wins = {}
  for winnr, win in pairs(fml.api.state.wins) do
    ---@type fml.types.api.state.IWinItemData
    local item = {
      winnr = winnr,
      filepath_history = win.filepath_history:dump(),
    }
    wins[winnr] = item
  end

  fc.reporter.info({
    from = "ghc.command.debug",
    subject = "show_editor_state",
    details = {
      tabnrs = vim.api.nvim_list_tabpages(),
      bufnrs = vim.api.nvim_list_bufs(),
      bufs = fml.api.state.bufs,
      tabs = fml.api.state.tabs,
      win_history = fml.api.state.win_history,
      wins = wins,
    },
  })
end

---@return nil
function M:show_input_state()
  local state = require("ghc.state.input_history").load_and_autosave()
  local data = {
    find_files = state.find_files:dump(),
    search_in_files = state.search_in_files:dump(),
  }
  fc.reporter.info({
    from = "ghc.command.debug",
    subject = "show_input_state",
    details = data,
  })
end

return M
