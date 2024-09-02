---@class ghc.command.term
local M = {}

---@return nil
function M.toggle_workspace()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = eve.path.workspace(),
  })
end

---@return nil
function M.toggle_cwd()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = eve.path.cwd(),
  })
end

---@return nil
function M.toggle_current()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = eve.path.current_directory(),
  })
end

---@return nil
function M.toggle_tmux()
  if eve.os.is_win() then
    M.toggle_workspace()
  else
    fml.api.term.toggle_or_create({
      name = "tmux",
      position = "float",
      command = "bash '" .. eve.path.locate_script_filepath("tmux.sh") .. "'",
      cwd = eve.path.workspace(),
    })
  end
end

return M
