---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.exit" ---@type string

local M = {}
local all = { qall = true, wqall = true, xall = true, cquit = true, restart = true }
local single = { quit = true, wq = true, xit = true, exit = true }

---@param command                       string
---@return boolean, boolean
local function exits(command)
  local tabs, tab = {}, 1
  for index, tabnr in ipairs(vim.api.nvim_list_tabpages()) do
    tabs[index] = 0
    for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(tabnr)) do
      local config = vim.api.nvim_win_get_config(winnr)
      if config.relative == "" and not config.external then
        tabs[index] = tabs[index] + 1
      end
    end
    if tabnr == vim.api.nvim_get_current_tabpage() then
      tab = index
    end
  end
  local current = vim.api.nvim_win_get_config(vim.api.nvim_get_current_win())
  local floating = current.relative ~= "" or current.external
  while command ~= "" do
    local ok, parsed = pcall(vim.api.nvim_parse_cmd, command, {})
    if not ok then
      return false, false
    end
    local cmd, nextcmd = parsed.cmd, parsed.nextcmd or ""
    if cmd == "wincmd" then
      local key, tail = parsed.args[1]:match("^%s*(%S)%s*|%s*(.*)$")
      key = key or parsed.args[1]
      nextcmd = tail or nextcmd
      cmd = ({ o = "only", q = "quit", c = "close", s = "split", v = "vsplit", n = "new" })[key] or cmd
    end
    local target_tab = tonumber(parsed.args[1]) or (parsed.range and parsed.range[1]) or tab
    if all[cmd] then
      return true, true
    elseif single[cmd] or cmd == "close" or cmd == "hide" then
      if not floating then
        if #tabs == 1 and tabs[tab] == 1 then
          if single[cmd] then
            return true, false
          end
        else
          tabs[tab] = tabs[tab] - 1
          if tabs[tab] == 0 then
            table.remove(tabs, tab)
            tab = math.min(tab, #tabs)
          end
        end
      end
      floating = false
    elseif cmd == "only" then
      tabs[tab], floating = 1, false
    elseif cmd == "tabonly" and tabs[target_tab] then
      tabs, tab, floating = { tabs[target_tab] }, 1, false
    elseif cmd == "tabclose" and #tabs > 1 and tabs[target_tab] then
      table.remove(tabs, target_tab)
      tab = math.max(1, math.min(tab - (target_tab < tab and 1 or 0), #tabs))
      floating = false
    elseif cmd == "tabnext" then
      tab = tonumber(parsed.args[1]) or (tab % #tabs + 1)
      tab = math.max(1, math.min(tab, #tabs))
      floating = false
    elseif cmd == "tabprevious" or cmd == "tabNext" then
      tab = (tab - 2) % #tabs + 1
      floating = false
    elseif cmd == "tabfirst" or cmd == "tabrewind" then
      tab, floating = 1, false
    elseif cmd == "tablast" then
      tab, floating = #tabs, false
    elseif
      cmd == "split"
      or cmd == "vsplit"
      or cmd == "new"
      or cmd == "vnew"
      or cmd == "snew"
      or cmd == "sfind"
      or cmd == "sbuffer"
      or cmd == "tabnew"
      or cmd == "tabedit"
      or cmd == "tabfind"
    then
      if cmd:sub(1, 3) == "tab" or parsed.mods.tab >= 0 then
        table.insert(tabs, tab + 1, 1)
        tab = tab + 1
      else
        tabs[tab] = tabs[tab] + 1
      end
      floating = false
    end
    command = nextcmd
  end
  return false, false
end

---@param jobs                          {pending: fun(): boolean, cancel_all: fun(): nil, poll: fun(): nil}
---@return nil
function M.setup(jobs)
  local pending_exit = false
  ---@param command                     string
  ---@return nil
  local function request(command)
    if pending_exit then
      return
    end
    local _, whole_editor = exits(command)
    local winnr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    pending_exit = true
    vim.ui.select(
      { "Wait", "Cancel operations and exit" },
      { prompt = "Explorer has unfinished file operations" },
      function(_, choice)
        if choice ~= 2 then
          pending_exit = false
          return
        end
        jobs.cancel_all()
        local started = vim.uv.hrtime()
        ---@return nil
        local function finish()
          jobs.poll()
          if jobs.pending() then
            if vim.uv.hrtime() - started > 10000000000 then
              pending_exit = false
              stl.reporter.warn({ from = __module_name__, message = "IO is still stopping; exit postponed" })
              return
            end
            vim.defer_fn(finish, 20)
            return
          end
          pending_exit = false
          if whole_editor then
            vim.cmd(command)
          elseif vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) == bufnr then
            vim.api.nvim_win_call(winnr, function()
              vim.cmd(command)
            end)
          end
        end
        finish()
      end
    )
  end
  local group = vim.api.nvim_create_augroup("ExplorerExit", { clear = true })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function(event)
      if not jobs.pending() or event.match ~= ":" or vim.v.event.abort then
        return
      end
      local command = vim.fn.getcmdline()
      if not exits(command) then
        return
      end
      -- v:event is a converted Lua table; mutate the actual Vim dictionary.
      vim.cmd("let v:event.abort = v:true")
      vim.schedule(function()
        request(command)
      end)
    end,
  })
  ---@type stl.t.IKeymap[]
  local keymaps = {}
  for key, command in pairs({ ZZ = "xit", ZQ = "quit!" }) do
    if vim.fn.maparg(key, "n") == "" then
      keymaps[#keymaps + 1] = {
        modes = { "n" },
        key = key,
        desc = "Quit after Explorer tasks stop",
        callback = function()
          if jobs.pending() and exits(command) then
            request(command)
          else
            vim.cmd(command)
          end
        end,
      }
    end
  end
  stl.nvim.fn.bindkeys(keymaps, { noremap = true, silent = true })
  vim.api.nvim_create_autocmd("ExitPre", {
    group = group,
    callback = function()
      if not jobs.pending() then
        return
      end
      -- Native/scripted quits cannot be vetoed by ExitPre. Finish cancellation before returning.
      jobs.cancel_all()
      while jobs.pending() do
        vim.wait(100, function()
          jobs.poll()
          return not jobs.pending()
        end, 10)
      end
    end,
  })
end

return M
