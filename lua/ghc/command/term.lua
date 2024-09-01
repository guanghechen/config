---@class ghc.command.term
local M = {}

---@return nil
function M.toggle_workspace()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = fc.path.workspace(),
  })
end

---@return nil
function M.toggle_cwd()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = fc.path.cwd(),
  })
end

---@return nil
function M.toggle_current()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = fc.path.current_directory(),
  })
end

---@return nil
function M.toggle_tmux()
  if fc.os.is_win() then
    M.toggle_workspace()
  else
    fml.api.term.toggle_or_create({
      name = "tmux",
      position = "float",
      command = "bash '" .. fc.path.locate_script_filepath("tmux.sh") .. "'",
      cwd = fc.path.workspace(),
    })
  end
end

return M
