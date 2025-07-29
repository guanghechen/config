local __module_name__ = "fml.action.term.create" ---@type string

---@class fml.action.term.create.IProfile
---@field public name                     string
---@field public type                     string
---@field public cmd                      string

---@class fml.action.term.create
local M = {}

---@type fml.action.term.create.IProfile[]
local profiles = {
  { name = "shell", type = "shell", cmd = vim.o.shell },
  { name = "claude", type = "claude", cmd = "claude" },
}

---@return nil
function M.show_profile_selector()
  local items = {} ---@type eve.ux.ISelectItem[]
  for _, profile in ipairs(profiles) do
    table.insert(items, {
      uuid = profile.name,
      text = profile.name,
    })
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local mouse = vim.fn.getmousepos()
  local select_widget = eve.ux.Select.new({
    items = items,
    wincfg = {
      title = "Select terminal profile:",
      width = 30,
      height = 3,
      relative = "win",
      win = winnr,
      row = 0,
      col = mouse.wincol - 3,
    },
    on_select = function(_, selected_item)
      if selected_item == nil then
        return
      end

      local selected_profile = nil ---@type fml.action.term.create.IProfile|nil
      for _, profile in ipairs(profiles) do
        if profile.name == selected_item.uuid then
          selected_profile = profile
          break
        end
      end

      if selected_profile then
        eve.term.create({
          uuid = oxi.fn.uuid(),
          type = selected_profile.type,
          name = selected_profile.name,
          cmd = selected_profile.cmd,
          permanent = false,
        })
        eve.ux.widget.Terminal:focus()
      end
    end,
  })

  select_widget:focus()
end

---@return nil
function M.rename()
  local termindex = eve.term.current() ---@type integer
  local _, termmeta = eve.term.at(termindex) ---@type string|nil, eve.builtin.term.IMeta|nil
  if termmeta == nil then
    std.reporter.warn({
      from = __module_name__,
      subject = "rename",
      message = "No active terminal found to rename.",
    })
    return
  end

  vim.ui.input({
    prompt = "Enter new terminal name: ",
    default = termmeta.name,
  }, function(new_name)
    if new_name == nil or #new_name == 0 then
      return -- User cancelled or entered empty name
    end

    if new_name == termmeta.name then
      return -- No change
    end

    eve.term.update(termmeta, { name = new_name })
    eve.status.dirtier_termline:mark_dirty()
  end)
end

---@return nil
function M.toggle()
  local cwd = std.path.cwd()
  local terminal = eve.ux.widget.Terminal ---@type eve.ux.widget.Terminal
  terminal:toggle_and_focus({
    uuid = "452e019a-3c93-439b-8671-8c418ef3516b",
    type = "shell",
    name = "shell",
    cwd = cwd,
    autofocus = true,
    permanent = true,
    selected_text = eve.buf.retrieve_selected_text(),
  })
end

return M
