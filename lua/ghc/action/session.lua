-- https://github.com/folke/persistence.nvim/blob/4982499c1636eac254b72923ab826ee7827b3084/lua/persistence/init.lua#L1

---@class ghc.action.session
local M = {}

---@return nil
function M.quit_all()
  vim.cmd("qa")
end

---@return nil
function M.save()
  if eve.path.is_git_repo() then
    eve.context.save({
      session = eve.context.storage.session,
      workspace = eve.context.storage.workspace,
    })
    eve.nvim.save_nvim_session(eve.context.storage.nvim_session)

    eve.reporter.info({
      from = "ghc.action.session",
      subject = "save",
      message = "Session saved successfully!",
    })
  end
end

---@return nil
function M.load()
  if eve.path.is_git_repo() then
    local nvim_session_filepath = nil ---@type string|nil
    if eve.context.storage.nvim_session and vim.fn.filereadable(eve.context.storage.nvim_session) ~= 0 then
      nvim_session_filepath = eve.context.storage.nvim_session
    elseif
      eve.context.storage.nvim_session_autosaved
      and vim.fn.filereadable(eve.context.storage.nvim_session_autosaved) ~= 0
    then
      nvim_session_filepath = eve.context.storage.nvim_session_autosaved
    end

    if nvim_session_filepath then
      eve.nvim.load_nvim_session(nvim_session_filepath)
    end

    eve.context.load({
      client = eve.context.storage.client,
      session = eve.context.storage.session,
      workspace = eve.context.storage.workspace,
    })
  end
end

return M
