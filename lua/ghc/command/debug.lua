local client = require("ghc.context.client")
local session = require("ghc.context.session")
local transient = require("ghc.context.transient")

---@class ghc.command.debug
local M = {}

function M.inspect()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string

  local winnr_cur = eve.widgets.get_current_winnr() ---@type integer|nil
  local bufnr_cur = eve.widgets.get_current_bufnr() ---@type integer|nil

  eve.reporter.info({
    from = "ghc.command.debug",
    subject = "inspect",
    details = {
      tabnr = tabnr,
      winnr = winnr,
      bufnr = bufnr,
      buftype = buftype or "nil",
      filetype = filetype or "nil",
      bufnr_cur = bufnr_cur,
      winnr_cur = winnr_cur,
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

  eve.reporter.info({
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

  eve.reporter.info({
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

  eve.reporter.info({
    from = "ghc.command.debug",
    subject = "show_editor_state",
    details = {
      tabnrs = vim.api.nvim_list_tabpages(),
      bufnrs = vim.api.nvim_list_bufs(),
      bufs = fml.api.state.bufs,
      tabs = fml.api.state.tabs,
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
  eve.reporter.info({
    from = "ghc.command.debug",
    subject = "show_input_state",
    details = data,
  })
end

---@return nil
function M.show_inspect_pos()
  vim.show_pos()
end

---@return nil
function M.show_inspect_tree()
  vim.cmd("InspectTree")
end

return M
