---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.ai.term" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("era.m.ai.term")

---@return era.m.ai.term
---@return table
local function setup()
  local calls = { starts = 0, stops = 0, detached = {}, scheduled = {}, exits = {}, reports = {}, bufnrs = {} }
  t:patch_global("stl", {
    filetype = { AI_TERMINAL = "ai-terminal" },
    nvim = {
      fn = { bindkeys = function() end },
      win = require("stl.nvim.win"),
      buf = {
        close = function(bufnr)
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
          end
        end,
      },
    },
    reporter = {
      error = function(report)
        calls.reports[#calls.reports + 1] = report
      end,
    },
  })
  t:patch_global("era", {
    m = {
      ai = {
        state = {
          detach_by_term_uuid = function(uuid)
            calls.detached[#calls.detached + 1] = uuid
          end,
        },
      },
    },
  })
  t:patch_table(vim, "schedule", function(callback)
    calls.scheduled[#calls.scheduled + 1] = callback
  end)
  t:patch_table(vim.fn, "jobstart", function(_, opts)
    calls.starts = calls.starts + 1
    local bufnr = vim.api.nvim_get_current_buf()
    calls.bufnrs[#calls.bufnrs + 1] = bufnr
    if calls.fail then
      return 0
    end
    local channel = vim.api.nvim_open_term(bufnr, {})
    calls.exits[channel] = opts.on_exit
    return channel
  end)
  t:patch_table(vim.fn, "jobstop", function(jobid)
    calls.stops = calls.stops + 1
    -- Exercise reentrant exit notification during explicit cleanup.
    calls.exits[jobid](jobid, 0)
    return 1
  end)

  local term = assert(loadfile("lua/era/m/ai/term.lua"))()
  t:defer(function()
    term.hide()
    for _, bufnr in ipairs(calls.bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  return term, calls
end

---@param term                          era.m.ai.term
---@param uuid                          string
---@return era.m.ai.term.IMeta
local function open(term, uuid)
  return term.open({ uuid = uuid, agent = "claude", cmd = { "mock-agent" }, cwd = vim.fn.getcwd() })
end

---@param calls                         table
---@return nil
local function drain(calls)
  while #calls.scheduled > 0 do
    table.remove(calls.scheduled, 1)()
  end
end

t:test("reopening a hidden live session restores its buffer without restarting the job", function()
  local term, calls = setup()
  local first = open(term, "A")
  local jobid = first.jobid
  term.hide()
  t.assert_false(term.isvisible(), "hidden window")

  local reopened = open(term, "A")
  t.assert_true(term.isvisible(), "reopened window")
  t.assert_true(reopened == first, "same session metadata")
  t.assert_eq(jobid, reopened.jobid, "same job")
  t.assert_eq(1, calls.starts, "no second process")
  t.assert_eq(first.bufnr, vim.api.nvim_win_get_buf(term.get_winnr()), "session buffer is displayed")
end)

t:test("switching between live sessions keeps the displayed buffer and current uuid aligned", function()
  local term, calls = setup()
  local first = open(term, "A")
  open(term, "B")
  local winnr = term.get_winnr()
  open(term, "A")
  t.assert_eq(winnr, term.get_winnr(), "shared window reused")
  t.assert_eq("A", term.get_current_uuid(), "selected session")
  t.assert_eq(first.bufnr, vim.api.nvim_win_get_buf(winnr), "selected buffer")
  t.assert_eq(2, calls.starts, "each session starts once")
end)

t:test("closing a background session preserves the foreground session and window", function()
  local term, calls = setup()
  local first = open(term, "A")
  local first_bufnr = first.bufnr
  local second = open(term, "B")
  local winnr = term.get_winnr()
  term.on_closed(first)

  t.assert_true(term.isvisible(), "foreground window remains visible")
  t.assert_eq(winnr, term.get_winnr(), "foreground window is retained")
  t.assert_eq(second.bufnr, vim.api.nvim_win_get_buf(winnr), "foreground buffer is retained")
  t.assert_eq("B", term.get_current_uuid(), "foreground identity")
  t.assert_false(vim.api.nvim_buf_is_valid(first_bufnr), "background buffer released")
  t.assert_eq(1, calls.stops, "background job stopped once")
  t.assert_eq("A", calls.detached[1], "only background source detached")
  t.assert_eq(1, #calls.detached, "reentrant exit is ignored")
end)

t:test("late close callbacks cannot remove a replacement session with the same uuid", function()
  local term, calls = setup()
  local first = open(term, "A")
  term.on_closed(first)
  t.assert_false(term.isvisible(), "closed foreground window")
  local replacement = open(term, "A")
  term.on_closed(first)
  drain(calls)

  t.assert_true(term.get("A") == replacement, "replacement still registered")
  t.assert_true(term.isvisible(), "replacement window survives stale cleanup")
  t.assert_eq(replacement.bufnr, vim.api.nvim_win_get_buf(term.get_winnr()), "replacement buffer")
  t.assert_eq(1, calls.stops, "old process stopped once")
  t.assert_eq(1, #calls.detached, "old source detached once")
end)

t:test("deferred focus does not steal focus after the user switches windows", function()
  local term, calls = setup()
  local source_winnr = vim.api.nvim_get_current_win()
  open(term, "A")
  vim.api.nvim_set_current_win(source_winnr)
  drain(calls)
  t.assert_eq(source_winnr, vim.api.nvim_get_current_win(), "newer user focus wins")
end)

t:test("focus resets horizontal scroll on the selected terminal", function()
  local term, calls = setup()
  local session = open(term, "A")
  drain(calls)
  local winnr = term.get_winnr()
  vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
  vim.api.nvim_chan_send(session.jobid, string.rep("x", 120))
  vim.fn.winrestview({ leftcol = 12 })
  t.assert_eq(12, vim.fn.winsaveview().leftcol, "horizontal scroll set")
  open(term, "A")
  drain(calls)
  t.assert_eq(0, vim.fn.winsaveview().leftcol, "terminal starts from its first column")
end)

t:test("failed startup cleanup does not hide a subsequently opened session", function()
  local term, calls = setup()
  calls.fail = true
  open(term, "A")
  calls.fail = false
  local second = open(term, "B")
  drain(calls)
  t.assert_nil(term.get("A"), "failed session released")
  t.assert_true(term.get("B") == second, "successful session retained")
  t.assert_true(term.isvisible(), "successful session remains visible")
  t.assert_eq("B", term.get_current_uuid(), "successful session remains selected")
  t.assert_eq(1, #calls.reports, "startup failure reported once")
end)

---@return era.m.ai
---@return table
---@return era.m.ai.picker.IShowAttachParams
local function setup_actions()
  local term, calls = setup()
  stl.c = {
    Observable = {
      from_value = function()
        return { next = function() end }
      end,
    },
  }
  stl.fn = { observe = function() end }
  stl.reporter.info = function() end
  stl.reporter.warn = function(report)
    calls.reports[#calls.reports + 1] = report
  end
  t:patch_global("dot", { path = { cwd = vim.fn.getcwd } })
  local ai = era.m.ai
  ai.term = term
  ai.config = {
    agent_labels = { claude = "claude" },
    tools = {
      claude = {
        cmd = "mock-agent",
        args = function()
          return {}
        end,
        env = function()
          return {}
        end,
      },
    },
  }
  ai.tmux = {
    is_available = function()
      return false
    end,
  }
  ai.state = assert(loadfile("lua/era/m/ai/state.lua"))()
  local params
  ai.picker = {
    show_attach = function(value)
      params = value
    end,
  }
  ai.action = assert(loadfile("lua/era/m/ai/action.lua"))()
  ai.action.show_attach_picker()
  return ai, calls, assert(params)
end

---@param id                            string
---@param source_type                   era.m.ai.SourceType
---@param external                      ?boolean
---@return era.m.ai.ISelectItem
local function running_item(id, source_type, external)
  return {
    type = "running",
    agent = "claude",
    installed = true,
    source = {
      id = source_type == "tmux" and ("tmux:" .. id) or id,
      type = source_type,
      agent = "claude",
      cwd = vim.fn.getcwd(),
      external = external == true,
      tmux_pane = source_type == "tmux" and { pane_id = id, session_name = "test-session" } or nil,
    },
  }
end

t:test("attach picker confirm reopens a hidden tmux session without detaching or restarting", function()
  local ai, calls, picker = setup_actions()
  local item = running_item("%999999", "tmux")
  picker.on_select(item)
  local session = ai.term.get("ai:claude:%999999")
  ai.term.hide()
  picker.on_select(item)
  t.assert_true(ai.term.isvisible(), "confirm restores the terminal")
  t.assert_true(ai.state.is_attached(item.source), "source stays attached")
  t.assert_eq(1, ai.state.get_attached_count(), "attachment is not duplicated")
  t.assert_true(ai.term.get(session.uuid) == session, "same terminal session")
  t.assert_eq(1, calls.starts, "same attach job")
  t.assert_eq(0, calls.stops, "confirm does not detach")
end)

t:test("attach picker confirm switches to an existing session without affecting its peer", function()
  local ai, calls, picker = setup_actions()
  local first = running_item("%999999", "tmux")
  local second = running_item("%999998", "tmux")
  picker.on_select(first)
  picker.on_select(second)
  picker.on_select(first)
  local session = ai.term.get("ai:claude:%999999")
  t.assert_eq(session.bufnr, vim.api.nvim_win_get_buf(ai.term.get_winnr()), "confirmed session is displayed")
  t.assert_eq(2, ai.state.get_attached_count(), "both sources remain attached")
  t.assert_eq(2, calls.starts, "no replacement jobs")
  t.assert_eq(0, calls.stops, "neither peer stopped")
end)

t:test("attach picker confirm restores a native session while preserving its source", function()
  local ai, calls, picker = setup_actions()
  local session = open(ai.term, "native-A")
  local item = running_item(session.uuid, "terminal")
  ai.state.attach(item.source)
  ai.term.hide()
  picker.on_select(item)
  t.assert_true(ai.term.isvisible(), "native terminal reopened")
  t.assert_eq(session.bufnr, vim.api.nvim_win_get_buf(ai.term.get_winnr()), "native buffer is reused")
  t.assert_true(ai.state.is_attached(item.source), "native source remains selectable")
  t.assert_eq(1, calls.starts, "native process is reused")
end)

t:test("attach picker toggle retains attach and detach behavior", function()
  local ai, calls, picker = setup_actions()
  local item = running_item("%999999", "tmux")
  picker.on_select(item)
  picker.on_toggle(item)
  t.assert_false(ai.state.is_attached(item.source), "toggle detaches")
  t.assert_false(ai.term.isvisible(), "detach closes the attach window")
  t.assert_eq(1, calls.stops, "attach process stopped")
  picker.on_toggle(item)
  t.assert_true(ai.state.is_attached(item.source), "toggle attaches again")
  t.assert_true(ai.term.isvisible(), "attach opens its window")
end)

t:test("confirming an external source only attaches the sending target", function()
  local ai, calls, picker = setup_actions()
  local item = running_item("%999999", "tmux", true)
  picker.on_select(item)
  picker.on_select(item)
  t.assert_true(ai.state.is_attached(item.source), "external source remains attached")
  t.assert_eq(1, ai.state.get_attached_count(), "one sending target")
  t.assert_eq(0, calls.starts, "no Neovim attach process")
  t.assert_false(ai.term.isvisible(), "no terminal window")
end)

t:test("confirming a native source that exited after the picker opened does not reattach it", function()
  local ai, _, picker = setup_actions()
  local session = open(ai.term, "native-A")
  local item = running_item(session.uuid, "terminal")
  ai.state.attach(item.source)
  ai.term.on_closed(session)
  picker.on_select(item)
  t.assert_false(ai.state.is_attached(item.source), "closed native source stays detached")
  t.assert_false(ai.term.isvisible(), "closed process is not reopened")
end)

t:test("attach picker confirm still creates a new native agent", function()
  local ai, calls, picker = setup_actions()
  picker.on_select({ type = "new", agent = "claude", installed = true })
  t.assert_eq(1, calls.starts, "new process started")
  t.assert_eq(1, ai.state.get_attached_count(), "new source attached")
  t.assert_true(ai.term.isvisible(), "new process displayed")
end)

t:run()
