---@class ghc.command.term
local M = {}

---@return nil
function M.toggle_workspace()
  fml.api.term.toggle_or_create({
    name = "workspace",
    cwd = eve.path.workspace(),
    permanent = true,
    send_selection_to_run = true,
  })
end

---@return nil
function M.toggle_cwd()
  fml.api.term.toggle_or_create({
    name = "workspace",
    cwd = eve.path.cwd(),
    permanent = true,
    send_selection_to_run = true,
  })
end

---@return nil
function M.toggle_current()
  fml.api.term.toggle_or_create({
    name = "workspace",
    cwd = eve.path.current_directory(),
    permanent = true,
    send_selection_to_run = true,
  })
end

---@return nil
function M.toggle_tmux()
  if eve.os.is_win() then
    M.toggle_workspace()
  else
    fml.api.term.toggle_or_create({
      name = "tmux",
      command = "bash '" .. eve.path.locate_script_filepath("tmux.sh") .. "'",
      cwd = eve.path.workspace(),
      permanent = true,
    })
  end
end

return M
