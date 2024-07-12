---@class ghc.command.term
local M = {}

---@return nil
function M.toggle_workspace()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = fml.path.workspace(),
  })
end

---@return nil
function M.toggle_cwd()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = fml.path.cwd(),
  })
end

---@return nil
function M.toggle_current()
  fml.api.term.toggle_or_create({
    name = "workspace",
    position = "float",
    cwd = fml.path.current_directory(),
  })
end

---@return nil
function M.toggle_tmux()
  if fml.os.is_win() then
    M.toggle_workspace()
  else
    fml.api.term.toggle_or_create({
      name = "tmux",
      position = "float",
      command = "bash '" .. fml.path.locate_script_filepath("tmux.sh") .. "'",
      cwd = fml.path.workspace(),
    })
  end
end

return M
