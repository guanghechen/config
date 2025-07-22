local __module_name__ = "fml.action.term.create" ---@type string

---@class fml.action.term.create.IProfile
---@field public name                     string
---@field public cmd                      string

---@class fml.action.term.create
local M = {}

---@type fml.action.term.create.IProfile[]
local profiles = {
  { name = "fish", cmd = "fish" },
  { name = "yazi", cmd = "yazi" },
  { name = "lazygit", cmd = "lazygit" },
}

---@return nil
function M.show_profile_selector()
  vim.ui.select(profiles, {
    name = __module_name__,
    prompt = "Select terminal profile:",
    format_item = function(profile)
      return profile.name
    end,
    dimension = {
      row = 3,
      width = 30,
    },
  }, function(selected_profile)
    if selected_profile == nil then
      return -- User cancelled
    end

    eve.term.create({
      uuid = oxi.fn.uuid(),
      name = selected_profile.name,
      cmd = selected_profile.cmd,
      permanent = false,
    })
    eve.ux.widget.Terminal:focus()
  end)
end

---@return nil
function M.rename()
  local current_term = eve.term.current() ---@type eve.builtin.term.IMeta|nil
  if current_term == nil then
    std.reporter.warn({
      from = __module_name__,
      subject = "rename",
      message = "No active terminal found to rename.",
    })
    return
  end

  vim.ui.input({
    prompt = "Enter new terminal name: ",
    default = current_term.name,
  }, function(new_name)
    if new_name == nil or #new_name == 0 then
      return -- User cancelled or entered empty name
    end

    if new_name == current_term.name then
      return -- No change
    end

    eve.term.update(current_term, { name = new_name })
    eve.status.dirtier_termline:mark_dirty()
  end)
end

return M