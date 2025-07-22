---@class fml.action.term.IProps
---@field public uuid                   string
---@field public name                   string
---@field public cmd                    ?string[]|string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public permanent              ?boolean
---@field public keymaps                ?std.t.IKeymap[]
---@field public on_closed              ?fun(): nil

---@class fml.action.term.toggle.IParams : fml.action.term.IProps
---@field public selected_text          string|nil

---@class fml.action.term
local M = {}

---@param params                        fml.action.term.toggle.IParams
---@return nil
function M.toggle(params)
  local uuid = params.uuid ---@type string
  local name = params.name ---@type string
  local termmeta = eve.term.resolve_by_name(name) ---@type eve.builtin.term.IMeta|nil
  if termmeta == nil then
    termmeta = eve.term.create({
      uuid = uuid,
      name = name,
      cmd = params.cmd,
      cwd = params.cwd,
      env = params.env,
      permanent = params.permanent,
      keymaps = params.keymaps,
      on_closed = params.on_closed,
    })
  else
    eve.term.update(termmeta, {
      name = name,
      cmd = params.cmd,
      env = params.env,
      on_closed = params.on_closed,
    })
  end

  local terminal = eve.ux.widget.Terminal ---@type eve.ux.widget.Terminal
  if terminal:isvisible() then
    local winnr = terminal:get_winnr() ---@type integer|nil
    if winnr ~= nil then
      local current_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local current_term = eve.term.resolve_by_bufnr(current_bufnr) ---@type eve.builtin.term.IMeta|nil
      if current_term ~= nil and current_term.name == name then
        terminal:hide()
        return terminal
      end
    end
  end

  eve.term.o_bufnr:next(termmeta.bufnr)
  terminal:focus()

  if terminal:isvisible() then
    local selected_text = params.selected_text ---@type string|nil
    if selected_text ~= nil and #selected_text > 0 then
      local winnr = terminal:get_winnr() ---@type integer|nil
      local bufnr = terminal:get_bufnr() ---@type integer|nil
      if winnr ~= nil and bufnr ~= nil then
        if selected_text and #selected_text > 1 then
          vim.api.nvim_set_current_win(winnr)
          vim.api.nvim_feedkeys("i" .. selected_text, "n", true)
        end
      end
    end
  end
  return terminal
end

---@return nil
function M.toggle_cwd()
  local cwd = std.path.cwd()
  M.toggle({
    uuid = "452e019a-3c93-439b-8671-8c418ef3516b#terminal",
    name = "cwd",
    cwd = cwd,
    permanent = true,
    selected_text = eve.buf.retrieve_selected_text(),
  })
end

return M
