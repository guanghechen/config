local __module_name__ = "eve.ux.widget.ai.term" ---@type string

---@class eve.ux.widget.ai.term.IMeta
---@field public uuid                   string
---@field public agent                  eve.ux.widget.ai.AgentName
---@field public bufnr                  integer
---@field public cmd                    string[]|string
---@field public cwd                    string
---@field public env                    table<string, string|false>|nil
---@field public jobid                  integer|nil

local DEFAULT_WIDTH = 100

local _metamap = {} ---@type table<string, eve.ux.widget.ai.term.IMeta>
local _winnr = nil ---@type integer|nil
local _current_uuid = nil ---@type string|nil

---@class eve.ux.widget.ai.term
local M = {}

---@return boolean
function M.isvisible()
  return _winnr ~= nil and vim.api.nvim_win_is_valid(_winnr)
end

---@return integer|nil
function M.get_winnr()
  return _winnr
end

---@return string|nil
function M.get_current_uuid()
  return _current_uuid
end

---@param uuid                          string
---@return eve.ux.widget.ai.term.IMeta|nil
function M.get(uuid)
  return _metamap[uuid]
end

---@param termmeta                      eve.ux.widget.ai.term.IMeta
---@return integer
local function create_buf(termmeta)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].filetype = eve.filetype.AI_TERMINAL
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = bufnr,
    callback = function()
      vim.schedule(function()
        M.on_closed(termmeta)
      end)
    end,
  })

  local keymaps = {
    { modes = { "n", "x" }, key = "q", desc = "ai term: close", callback = M.hide },
    {
      modes = { "i", "n", "t", "x" },
      key = "<esc>",
      desc = "ai term: feedback esc",
      expr = true,
      replace_keycodes = true,
      callback = function()
        return "<esc>"
      end,
    },
    {
      modes = { "i", "n", "t", "x" },
      key = "<M-h>",
      desc = "ai term: navigate left",
      callback = function()
        require("fml.action.win.focus").navigate("h")
      end,
    },
    {
      modes = { "i", "n", "t", "x" },
      key = "<M-j>",
      desc = "ai term: navigate down",
      callback = function()
        require("fml.action.win.focus").navigate("j")
      end,
    },
    {
      modes = { "i", "n", "t", "x" },
      key = "<M-k>",
      desc = "ai term: navigate up",
      callback = function()
        require("fml.action.win.focus").navigate("k")
      end,
    },
    {
      modes = { "i", "n", "t", "x" },
      key = "<M-l>",
      desc = "ai term: navigate right",
      callback = function()
        require("fml.action.win.focus").navigate("l")
      end,
    },
  }
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  termmeta.bufnr = bufnr
  return bufnr
end

---@param termmeta                      eve.ux.widget.ai.term.IMeta
---@return integer
local function create_win(termmeta)
  local winnr = _winnr
  local bufnr = termmeta.bufnr

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.wo[winnr].winfixbuf = true
    vim.api.nvim_set_current_win(winnr)
  else
    vim.cmd("botright vsplit")
    winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_width(winnr, DEFAULT_WIDTH)

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].winfixbuf = true
    vim.wo[winnr].winfixwidth = true
    vim.wo[winnr].wrap = true

    _winnr = winnr
  end

  vim.schedule(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
      vim.cmd("startinsert")
    end
  end)

  return winnr
end

---@param termmeta                      eve.ux.widget.ai.term.IMeta
---@return nil
local function start_job(termmeta)
  if termmeta.jobid ~= nil then
    return
  end

  local winnr = create_win(termmeta)
  vim.api.nvim_tabpage_set_win(vim.api.nvim_get_current_tabpage(), winnr)

  local channelid = vim.fn.jobstart(termmeta.cmd, {
    cwd = termmeta.cwd,
    env = termmeta.env,
    pty = true,
    term = true,
    detach = false,
    on_exit = function(jobid, code, _)
      if code ~= 0 and code ~= 1 and code ~= 129 then
        std.reporter.error({
          from = __module_name__,
          subject = "terminal unexpected exit",
          details = { uuid = termmeta.uuid, agent = termmeta.agent, cmd = termmeta.cmd, cwd = termmeta.cwd, code = code },
        })
      end
      if termmeta.jobid == jobid then
        termmeta.jobid = nil
        M.on_closed(termmeta)
      end
    end,
  })
  termmeta.jobid = channelid
end

---@class eve.ux.widget.ai.term.IOpenParams
---@field public uuid                   string
---@field public agent                  eve.ux.widget.ai.AgentName
---@field public cmd                    string[]|string
---@field public cwd                    string
---@field public env                    ?table<string, string|false>

---@param params                        eve.ux.widget.ai.term.IOpenParams
---@return eve.ux.widget.ai.term.IMeta
function M.open(params)
  local termmeta = params.uuid ~= "" and _metamap[params.uuid] or nil

  if termmeta == nil then
    termmeta = {
      uuid = params.uuid,
      agent = params.agent,
      bufnr = 0,
      cmd = params.cmd,
      cwd = params.cwd,
      env = params.env,
      jobid = nil,
    }
    create_buf(termmeta)

    if params.uuid == "" then
      termmeta.uuid = tostring(termmeta.bufnr)
    end
    _metamap[termmeta.uuid] = termmeta
  end

  _current_uuid = termmeta.uuid
  start_job(termmeta)
  return termmeta
end

---@return nil
function M.hide()
  local winnr = _winnr
  _winnr = nil
  eve.win.close(winnr)
end

---@param termmeta                      eve.ux.widget.ai.term.IMeta
---@return nil
function M.on_closed(termmeta)
  local state = require("eve.ux.widget.ai.state")

  if termmeta.jobid ~= nil then
    vim.fn.jobstop(termmeta.jobid)
    termmeta.jobid = nil
  end

  local bufnr = termmeta.bufnr
  termmeta.bufnr = 0
  _metamap[termmeta.uuid] = nil

  if _current_uuid == termmeta.uuid then
    _current_uuid = nil
  end

  state.detach_by_term_uuid(termmeta.uuid)

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    eve.buf.close(bufnr)
  end

  if M.isvisible() then
    M.hide()
  end

  vim.schedule(function()
    vim.cmd("checktime")
  end)
end

---@param uuid                          string
---@return boolean
function M.is_alive(uuid)
  local termmeta = _metamap[uuid]
  return termmeta ~= nil and termmeta.bufnr > 0 and vim.api.nvim_buf_is_valid(termmeta.bufnr)
end

---@param uuid                          string
---@param text                          string
---@param submit                        boolean
---@return boolean
function M.send(uuid, text, submit)
  local termmeta = _metamap[uuid]
  if termmeta == nil or termmeta.jobid == nil then
    return false
  end

  if not M.is_alive(uuid) then
    return false
  end

  local payload = submit and (text .. "\n") or text
  local ok, err = pcall(vim.api.nvim_chan_send, termmeta.jobid, payload)

  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "send",
      message = "Failed to send text to terminal.",
      details = { error = err },
    })
    return false
  end

  return true
end

return M
