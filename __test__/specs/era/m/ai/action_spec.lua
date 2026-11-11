local support = require("__test__.support.ai")
local harness = require("__test__.support.harness")
local t = harness.new()

---@return era.m.ai
---@return __test__.support.ai.ICalls
---@return era.m.ai.picker.IShowAttachParams
local function setup_actions()
  local term, calls = support.term(t)
  stl.c = {
    Observable = {
      from_value = function()
        return { next = function() end }
      end,
    },
  }
  stl.fn = { observe = function() end }
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
  local session = support.open(ai.term, "native-A")
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
  local session = support.open(ai.term, "native-A")
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
