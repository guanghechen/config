local constant = require("fml.constant")
local state = require("fml.api.state")
local reporter = require("eve.std.reporter")

---@class fml.api.term
local M = {}

---@class fml.api.term.ICreateParams
---@field public name                   string
---@field public position               eve.enums.TermPosition
---@field public command                ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>

---@param position                      eve.enums.TermPosition
---@param subject                       string
---@return boolean
local function validate_position(position, subject)
  if position == "float" or position == "bottom" or position == "right" then
    return true
  end

  reporter.error({
    from = "fml.api.term",
    subject = subject,
    message = "Not recognized term position.",
    details = { position = position },
  })
  return false
end

---@return integer
function M.create_term_buf()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = constant.FT_TERM
  vim.bo[bufnr].swapfile = false

  ---@return nil
  local function close_buf()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  vim.keymap.set({ "n" }, "q", close_buf, { desc = "close", noremap = true, silent = true })
  return bufnr
end

---@param position                      eve.enums.TermPosition
---@param bufnr                         integer|nil
---@return integer|nil
---@return integer|nil
function M.create_term_win(position, bufnr)
  if not validate_position(position, "create_term_win") then
    return
  end

  bufnr = (bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)) and bufnr or M.create_term_buf() ---@type integer
  if position == "float" then
    local width = math.ceil(0.9 * vim.o.columns) ---@type integer
    local height = math.ceil(0.9 * vim.o.lines) ---@type integer
    local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
    local col = math.floor((vim.o.columns - width) / 2) ---@type integer
    vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      height = height,
      width = width,
      row = row,
      col = col,
      focusable = true,
      title = "",
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    })
  elseif position == "bottom" then
    vim.cmd("split")
  elseif position == "right" then
    vim.cmd("vplit")
  end

  local winnr = vim.api.nvim_get_current_win()
  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "no"

  if position == "float" then
    vim.wo[winnr].winblend = 20
  end
  return winnr, bufnr
end

---@param params                        fml.api.term.ICreateParams
---@return integer|nil
function M.create(params)
  local name = params.name ---@type string
  local command = params.command or vim.env.SHELL or vim.o.shell ---@type string
  local position = params.position ---@type eve.enums.TermPosition

  local term = state.term_map[name] ---@type fml.types.api.state.ITerm|nil
  if term ~= nil then
    reporter.error({
      from = "fml.api.term",
      subject = "create",
      message = "The term with the given name already exists.",
      details = { name = name, command = command, position = position },
    })
    return
  end

  local winnr, bufnr = M.create_term_win(position, nil) ---@type integer|nil
  if winnr == nil or bufnr == nil then
    reporter.error({
      from = "fml.api.term",
      subject = "create",
      message = "Failed to creat the term window.",
      details = {
        name = name,
        command = command,
        position = position,
        bufnr = bufnr or "nil",
        winnr = winnr or "nil",
      },
    })
    return
  end

  ---@type fml.types.api.state.ITerm
  term = {
    name = name,
    bufnr = bufnr,
    position = position,
    winnr = winnr,
  }
  state.term_map[name] = term

  vim.fn.termopen(command, { cwd = params.cwd, env = params.env })
  vim.api.nvim_create_autocmd("TermClose", {
    once = true,
    buffer = bufnr,
    callback = function()
      local term_winnr = term and term.winnr ---@type integer|nil
      if term_winnr and vim.api.nvim_win_is_valid(term_winnr) then
        term.winnr = nil
        vim.api.nvim_win_close(term_winnr, true)
        vim.cmd("redraw")
      end
      state.term_map[name] = nil
    end,
  })

  vim.schedule(function()
    vim.cmd("startinsert")
  end)

  return bufnr
end

---@param name                          string
---@return integer|nil
function M.toggle(name)
  local term = state.term_map[name] ---@type fml.types.api.state.ITerm|nil
  if term == nil then
    reporter.error({
      from = "fml.api.term",
      subject = "toggle",
      message = "Cannot find the term with the given name.",
      details = { name = name },
    })
    return
  end

  if term.winnr ~= nil then
    local winnr = term.winnr ---@type integer
    term.winnr = nil
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, false)
    end
    return
  end

  local winnr, bufnr = M.create_term_win(term.position, term.bufnr) ---@type integer|nil
  if winnr == nil or bufnr == nil then
    reporter.error({
      from = "fml.api.term",
      subject = "toggle",
      message = "Failed to creat the term window.",
      details = { name = name },
    })
    return
  end

  term.winnr = winnr
  term.bufnr = bufnr
  vim.api.nvim_win_set_buf(winnr, term.bufnr)
  vim.api.nvim_tabpage_set_win(0, winnr)

  vim.schedule(function()
    vim.cmd("startinsert")
  end)

  return bufnr
end

---@param params                        fml.api.term.ICreateParams
---@return integer|nil
function M.toggle_or_create(params)
  if state.term_map[params.name] == nil then
    return M.create(params)
  else
    return M.toggle(params.name)
  end
end

return M
