local __module_name__ = "fml.action.term.create" ---@type string

---@class fml.action.term.create.IProfile
---@field public name                   string
---@field public type                   string
---@field public cmd                    string

---@class fml.action.term.create
local M = {}

---@type fml.action.term.create.IProfile[]
local profiles = {
  { name = "shell", type = "shell", cmd = vim.o.shell },
}

---@param profile                       fml.action.term.create.IProfile|nil
---@return nil
local function apply_profile(profile)
  if profile == nil then
    return
  end

  eve.term.create({
    uuid = yoz.fn.uuid(),
    type = profile.type,
    name = profile.name,
    cmd = profile.cmd,
    permanent = false,
  })
  ux.widget.Terminal:focus()
end

---@return nil
function M.show_profile_selector()
  local profile_count = #profiles ---@type integer
  if profile_count == 1 then
    apply_profile(profiles[1])
    return
  end

  local items = {} ---@type ux.ISelectItem[]
  for _, profile in ipairs(profiles) do
    table.insert(items, {
      uuid = profile.name,
      text = profile.name,
    })
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local mouse = vim.fn.getmousepos()
  local select_widget = ux.Select.new({
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
        apply_profile(selected_profile)
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
    ark.reporter.warn({
      from = __module_name__,
      subject = "rename",
      message = "No active terminal found to rename.",
    })
    return
  end

  ---@type fml.dressing.input.IOptions
  local input_opts = {
    prompt = "Enter new terminal name: ",
    default = termmeta.name,
  }

  local terminal_widget = ux.widget.Terminal ---@type ux.widget.Terminal
  local winnr = terminal_widget:get_winnr() ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    local available_width = nil ---@type integer|nil
    local ok_width, width_value = pcall(vim.api.nvim_win_get_width, winnr)
    if ok_width and type(width_value) == "number" then
      available_width = width_value
    else
      local ok_cfg, cfg = pcall(vim.api.nvim_win_get_config, winnr)
      if ok_cfg and type(cfg) == "table" and type(cfg.width) == "number" then
        available_width = cfg.width
      end
    end

    if type(available_width) == "number" and available_width > 0 then
      local max_width = math.max(1, available_width - 2) ---@type integer
      local width = math.min(60, math.max(20, max_width)) ---@type integer
      width = math.min(width, max_width)
      local col = math.max(0, math.floor((available_width - width) / 2)) ---@type integer

      input_opts.relative = "win"
      input_opts.win = winnr
      input_opts.width = width
      input_opts.row = 1
      input_opts.col = col
    else
      input_opts.relative = "win"
      input_opts.win = winnr
      input_opts.row = 1
      input_opts.col = 0
    end
  end

  vim.ui.input(input_opts, function(new_name)
    if new_name == nil or #new_name == 0 then
      return -- User cancelled or entered empty name
    end

    if new_name == termmeta.name then
      return -- No change
    end

    eve.term.update(termmeta, { name = new_name })
    std.status.dirtier_termline:mark_dirty()
  end)
end

---@return nil
function M.toggle()
  local cwd = std.path.cwd()
  local terminal = ux.widget.Terminal ---@type ux.widget.Terminal

  if terminal:isvisible() then
    local termindex = eve.term.current() ---@type integer
    local _, termmeta = eve.term.at(termindex) ---@type string|nil, eve.builtin.term.IMeta|nil
    if termmeta ~= nil and (termmeta.type == "runner" or termmeta.type == "shell") then
      terminal:toggle()
      return
    end
  else
    terminal:focus()
    local termindex = eve.term.current() ---@type integer
    local _, termmeta = eve.term.at(termindex) ---@type string|nil, eve.builtin.term.IMeta|nil
    if termmeta ~= nil and (termmeta.type == "runner" or termmeta.type == "shell") then
      return
    end
  end

  local _, termmeta = eve.term.find_index_by_type("shell") ---@type integer, eve.builtin.term.IMeta|nil
  if termmeta == nil then
    terminal:toggle_and_focus({
      uuid = yoz.fn.uuid(),
      type = "shell",
      name = "shell",
      cwd = cwd,
      autofocus = true,
      permanent = true,
      selected_text = eve.buf.retrieve_selected_text(),
    })
  else
    terminal:toggle_and_focus({
      uuid = termmeta.uuid,
      type = termmeta.type,
      name = termmeta.name,
      cwd = termmeta.cwd,
      autofocus = true,
      permanent = true,
      selected_text = eve.buf.retrieve_selected_text(),
    })
  end
end

return M
