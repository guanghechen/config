local client = require("ghc.context.client")
local session = require("ghc.context.session")
local transient = require("ghc.context.transient")

---@class ghc.command.debug
local M = {}

function M.inspect()
  fml.reporter.info({
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
    config = client:get_snapshot(),
    session = session:get_snapshot(),
    transient = transient:get_snapshot(),
  }

  fml.reporter.info({
    from = "ghc.command.debug",
    subject = "show_context",
    details = context,
  })
end

---@return nil
function M.show_context_all()
  local context = {
    config = vim.tbl_deep_extend("force", { _location = ghc.context.client:get_filepath() }, client:get_snapshot_all()),
    session = vim.tbl_deep_extend(
      "force",
      { _location = ghc.context.session:get_filepath() },
      session:get_snapshot_all()
    ),
    transient = vim.tbl_deep_extend("force", {}, transient:get_snapshot_all()),
  }

  fml.reporter.info({
    from = "ghc.command.debug",
    subject = "show_context_all",
    details = context,
  })
end

function M.show_state()
  fml.reporter.info({
    from = "ghc.command.debug",
    subject = "show_state",
    details = {
      tabnrs = vim.api.nvim_list_tabpages(),
      bufnrs = vim.api.nvim_list_bufs(),
      bufs = fml.api.state.bufs,
      tabs = fml.api.state.tabs,
    },
  })
end

return M
