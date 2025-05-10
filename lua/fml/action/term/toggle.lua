local __module_name__ = "fml.action.term" ---@type string

local terminal_map = {} ---@type table<string, eve.ux.ITerminal>

---@class fml.action.term.IProps
---@field public name                   string
---@field public cmd                    ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public permanent              ?boolean
---@field public title                  ?string
---@field public on_exit                ?fun(): nil

---@class fml.action.term.toggle.IParams : fml.action.term.IProps
---@field public selected_text          string|nil

---@class fml.action.term
local M = {}

---@param props                        fml.action.term.IProps
---@return eve.ux.ITerminal
function M.new(props)
  local name = props.name ---@type string
  local cmd = props.cmd or vim.env.SHELL or vim.o.shell ---@type string
  local cwd = props.cwd or eve.path.cwd() ---@type string
  local env = props.env ---@type table<string, string>|nil
  local permanent = props.permanent ---@type boolean|nil
  local title = props.title ---@type string|nil

  local terminal = terminal_map[name] ---@type eve.ux.ITerminal|nil
  if terminal ~= nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "new",
      message = "The term with the given name already exists.",
      details = { name = name, cmd = cmd, cwd = cwd, env = env },
    })
    return terminal
  end

  ---@type eve.ux.ITerminal
  terminal = eve.ux.Terminal.new({
    cmd = cmd,
    cwd = cwd,
    env = env,
    permanent = permanent,
    title = title,
  })
  terminal_map[name] = terminal

  terminal:focus()
  return terminal
end

---@param params                        fml.action.term.toggle.IParams
---@return eve.ux.ITerminal
function M.toggle(params)
  local name = params.name ---@type string

  local terminal = terminal_map[name] ---@type eve.ux.ITerminal|nil
  if terminal == nil or terminal:isdisposed() then
    terminal_map[name] = nil
    terminal = M.new(params)
  else
    terminal:update({
      cmd = params.cmd,
      cwd = params.cwd,
      env = params.env,
      title = params.title,
      on_exit = params.on_exit,
    })
    terminal:toggle()
  end

  if terminal:isvisible() then
    local selected_text = params.selected_text ---@type string|nil
    if selected_text ~= nil and #selected_text > 0 then
      local winnr = terminal:get_winnr() ---@type integer|nil
      local bufnr = terminal:get_bufnr() ---@type integer|nil
      if winnr ~= nil and bufnr ~= nil then
        if selected_text and #selected_text > 1 then
          vim.api.nvim_set_current_win(winnr)
          vim.api.nvim_feedkeys("i" .. selected_text, "n", true) -- Insert the text without newline
        end
      end
    end
  end
  return terminal
end

---@return nil
function M.toggle_cwd()
  local cwd = eve.path.cwd()

  M.toggle({
    name = "cwd",
    cwd = cwd,
    permanent = true,
    selected_text = eve.buf.retrieve_selected_text(),
  })
end

---@return nil
function M.toggle_directory()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local cwd = eve.path.dirname(filepath) ---@type string

  M.toggle({
    name = "directory",
    cwd = cwd,
    permanent = true,
    selected_text = eve.buf.retrieve_selected_text(),
  })
end

---@return nil
function M.toggle_workspace()
  local cwd = eve.path.workspace()

  M.toggle({
    name = "workspace",
    cwd = cwd,
    permanent = true,
    selected_text = eve.buf.retrieve_selected_text(),
  })
end

return M
