---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.explorer" ---@type string

local Grid = require("__test__.support.ui_grid")
local UI = require("__test__.support.ui")

local M = {}

---@class __test__.support.explorer.IOpenUi
---@field width                         integer
---@field height                        integer
---@field path                          string
---@field git_repo                      ?boolean
---@field on_flush                      ?fun(grid: table): nil Called with the screen grid at each flush.

---Starts an Explorer UI child that closes when the case ends, with a screen grid fed from its first redraw: a
---linegrid UI, the native library, the real stl/dot/era modules with `path` as the workspace, and reporter warnings
---and errors collected as messages in the child's global `errors`. In the child, `await(future)` waits for a Future
---and returns its result, raising when it fails, and `shown(widget, count, ready)` waits until `widget` shows `count`
---rows in the current tab and `ready(session, view)`, when given, holds, and returns that session and view.
---@param t                             __test__.support.Harness
---@param options                       __test__.support.explorer.IOpenUi
---@return __test__.support.UI ui
---@return table grid
function M.open_ui(t, options)
  local ui = UI.open(t)
  local grid = Grid.new(ui, options.on_flush)
  ui:start({ width = options.width, height = options.height, runtime = "native" })
  ui:lua(
    [[
    local path, git_repo = ...
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return git_repo end
    errors = {}
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = stl.reporter.warn
    stl.reporter.info = function() end
    function await(future)
      assert(vim.wait(10000, function() return future:is_done() end, 1), "future did not settle within 10000 ms")
      assert(not future:is_failed(), future:get_error())
      return future:get_result()
    end
    function shown(widget, count, ready)
      local session, view
      assert(vim.wait(10000, function()
        local ok
        ok, session, view = pcall(widget.context, widget)
        return ok and view ~= nil and view:frame() ~= nil and view:frame():header().row_count == count
          and (ready == nil or ready(session, view))
      end, 1), "the Explorer did not show " .. count .. " rows within 10000 ms")
      return session, view
    end
  ]],
    options.path,
    options.git_repo == true
  )
  return ui, grid
end

---@class __test__.support.explorer.IPromptContext
---@field ui                            __test__.support.UI
---@field grid                          table
---@field path                          string

---@class __test__.support.explorer.IPrompt
---@field open                          fun(names: string[]): __test__.support.explorer.IPromptContext
---@field dialog                        fun(context: __test__.support.explorer.IPromptContext): table
---@field answer                        fun(context: __test__.support.explorer.IPromptContext, keys: string): nil

---Prompt helpers for the cases of `t`. `open(names)` writes `names` to a new directory, each file holding its own
---name and a name ending in "/" making a directory, and starts an Explorer UI child, as `open_ui` does, whose
---`widget`, `session` and `view` show that directory once it settles; the child answers `vim.ui.input` with
---`era.m.input` and fails any picker. `dialog(context)` waits for the input dialog and returns its height, width, lines
---and wrap, asserting that it is the only floating window and stays anchored to the Explorer window. `answer(context,
---keys)` types `keys` and waits until the operation settles back in the Explorer, asserting that nothing reported an
---error.
---@param t                             __test__.support.Harness
---@return __test__.support.explorer.IPrompt
function M.prompt(t)
  local prompt = {} ---@type __test__.support.explorer.IPrompt

  function prompt.open(names)
    local path = t:tempdir()
    for _, name in ipairs(names) do
      if name:sub(-1) == "/" then
        assert(vim.uv.fs_mkdir(path .. "/" .. name:sub(1, -2), 448))
      else
        vim.fn.writefile({ name }, path .. "/" .. name)
      end
    end
    local ui, grid = M.open_ui(t, { width = 142, height = 69, path = path })
    ui:lua(
      [[
      local path, count = ...
      dot.context.explorer.trash.snapshot = function() return false end
      vim.ui.input = require("era.m.input").open
      vim.ui.select = function() error("a confirmation must not open a picker") end
      widget = require("era.m.explorer.widget").new({ name = "compact-prompt", root = path })
      widget:focus()
      session, view = shown(widget, count, function(current_session, current)
        return not current_session.data:native():is_busy() and current_session.state:native():applicable(current:frame())
      end)
    ]],
      path,
      #names
    )
    return { ui = ui, grid = grid, path = path }
  end

  function prompt.dialog(context)
    local result
    context.ui:wait_until(function()
      result = context.ui:lua([[
        local result, floats = nil, 0
        for _, winnr in ipairs(vim.api.nvim_list_wins()) do
          local config = vim.api.nvim_win_get_config(winnr)
          if config.relative ~= "" then floats = floats + 1 end
          if vim.w[winnr].wintype == stl.e.WinTypeEnum.INPUT then
            local bufnr = vim.api.nvim_win_get_buf(winnr)
            result = {
              height = config.height, width = config.width, relative = config.relative,
              origin = config.win == view.winnr,
              lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
              wrap = vim.api.nvim_get_option_value("wrap", {win = winnr}),
            }
          end
        end
        if result then result.floats = floats end
        return result
      ]])
      return result ~= nil
    end, 10000, "the input dialog must open")
    t.assert_eq(1, result.floats, "confirmation must use one compact surface")
    t.assert_eq("win", result.relative)
    t.assert_true(result.origin, "confirmation must stay anchored to the Explorer window")
    return result
  end

  function prompt.answer(context, keys)
    context.ui:rpc("nvim_input", keys)
    context.ui:wait_lua(
      "return not session:busy() and vim.api.nvim_get_current_win() == view.winnr",
      10000,
      "the answer must settle the operation and return to the Explorer"
    )
    local errors = context.ui:lua("return errors")
    t.assert_eq(0, #errors, vim.inspect(errors))
  end

  return prompt
end

---@param view                          ?ux.filetree.View
---@return boolean
local function published(view)
  local frame = view and view:frame()
  return frame ~= nil and not view:status().preparing and view._latest == nil and view._state:native():applicable(frame)
end

---Loads the real stl/dot/era runtime for the suite of `t`, with reporter warnings and infos collected as messages and
---errors raised.
---@param t                             __test__.support.Harness
---@return table
function M.new(t)
  local fixture = require("__test__.support.filetree").new(t)
  t:patch_global("stl", require("stl"))
  t:patch_global("dot", require("dot"))
  t:patch_global("era", require("era"))
  local messages, infos = {}, {}
  t:patch_table(stl.reporter, "warn", function(value)
    messages[#messages + 1] = value.message
  end)
  t:patch_table(stl.reporter, "error", function(value)
    error(value.message)
  end)
  t:patch_table(stl.reporter, "info", function(value)
    infos[#infos + 1] = value.message
  end)
  t:patch_table(dot.path, "is_git_repo", function()
    return false
  end)
  local Widget = require("era.m.explorer.widget")
  local Observable = require("stl.c.observable")

  ---Creates a Widget from `props`, disposed when the case ends; unlike `widget`, it neither opens nor waits.
  ---@param props                       table
  ---@return era.m.explorer.Widget
  function fixture.create(props)
    local widget = Widget.new(props)
    t:defer(function()
      widget:dispose()
    end)
    return widget
  end

  ---@param path                        string
  ---@param options                     ?table
  ---@return era.m.explorer.Widget
  function fixture.widget(path, options)
    t:patch_table(dot.path, "workspace", function()
      return path
    end)
    local widget = fixture.create(vim.tbl_extend("force", {
      name = "test-" .. vim.uv.hrtime(),
      root = path,
      o_width = Observable.from_value(30),
      o_flag_selected = Observable.from_value(false),
      o_flag_viewtype = Observable.from_value("tree"),
      o_flag_foldempty = Observable.from_value(true),
      o_flag_hidden = Observable.from_value(true),
    }, options or {}))
    widget:focus()
    t.wait_until(function()
      local session, view = fixture.context(widget)
      return published(view) and not session.data:native():is_busy()
    end, 10000)
    return widget
  end

  ---The current tab's session and view, as `widget:context()` returns them, or nothing while the Explorer is still
  ---opening there.
  ---@param widget                      era.m.explorer.Widget
  ---@return era.m.explorer.Session|nil
  ---@return ux.filetree.View|nil
  function fixture.context(widget)
    local ok, session, view = pcall(widget.context, widget)
    if ok then
      return session, view
    end
  end

  ---Waits until the Explorer shows a frame in the current tab, one of `count` rows when given.
  ---@param widget                      era.m.explorer.Widget
  ---@param count                       ?integer
  ---@return nil
  function fixture.shown(widget, count)
    t.wait_until(function()
      local _, view = fixture.context(widget)
      return view ~= nil and view:frame() ~= nil and (count == nil or view:frame():header().row_count == count)
    end, 10000)
  end

  ---@param widget                      era.m.explorer.Widget
  ---@param path                        string
  ---@return yoz.ux.filetree.Resource
  function fixture.cursor(widget, path)
    local session, view = widget:context()
    local resource = fixture.await(session.data:resolve(path))
    t.wait_until(function()
      return view:frame() and view:frame():position(resource:node()) ~= nil
    end, 10000)
    fixture.await(view:set_cursor(view:frame():position(resource:node())))
    return resource
  end

  ---Waits until `session` has no preparation, Job, lock or native read in flight and each of its open views shows its
  ---latest frame. A hidden Explorer has no context, so tests that hide it settle the session they captured.
  ---@param session                     era.m.explorer.Session
  ---@return nil
  function fixture.settle(session)
    t.wait_until(function()
      -- Native reads may finish while the latest source frame is still paced.
      for view in pairs(session.views) do
        if not view._closed and not published(view) then
          return false
        end
      end
      return not session.preparing
        and session.job == nil
        and not session.state:status().locked
        and not session.data:native():is_busy()
    end, 10000)
  end

  ---Waits until the Explorer is open in the current tab and its session has settled.
  ---@param widget                      era.m.explorer.Widget
  ---@return nil
  function fixture.idle(widget)
    local session ---@type era.m.explorer.Session|nil
    t.wait_until(function()
      session = fixture.context(widget)
      return session ~= nil
    end, 10000)
    fixture.settle(assert(session))
  end

  ---Waits until `widget` is open in the current tab on the display root `path`, and its session has settled.
  ---@param widget                      era.m.explorer.Widget
  ---@param path                        string
  ---@return nil
  function fixture.root_is(widget, path)
    t.wait_until(function()
      return fixture.context(widget) ~= nil and widget:get_root_filepath() == path
    end, 10000)
    fixture.idle(widget)
  end

  ---An Explorer on a new directory holding the file `a`, where its cursor is, and the empty directory `branch`, where a
  ---case can materialize source updates unrelated to `a`.
  ---@return era.m.explorer.Widget widget
  ---@return string path
  function fixture.file_and_branch()
    local path = t:tempdir()
    fixture.write(path .. "/a")
    assert(vim.uv.fs_mkdir(path .. "/branch", 448))
    local widget = fixture.widget(path)
    fixture.cursor(widget, path .. "/a")
    return widget, path
  end

  ---Marks the cursor row or Visual range of `widget` for `purpose` and waits until its view can show the committed
  ---selection.
  ---@param widget                      era.m.explorer.Widget
  ---@param purpose                     string
  ---@return nil
  function fixture.mark(widget, purpose)
    local result = fixture.await(widget:action():mark(purpose))
    local session, view = widget:context()
    if result.revisions then
      t.wait_until(function()
        return session.state:native():applicable(view:frame(), result.revisions.commit)
      end, 10000)
    end
  end

  ---Types `keys` and runs them before returning.
  ---@param keys                        string
  ---@return nil
  function fixture.press(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
  end

  ---Asserts that `session` selects the single subtree of `node` for `purpose`, or nothing when `node` is nil.
  ---@param session                     era.m.explorer.Session
  ---@param node                        ?string
  ---@param purpose                     ?string
  ---@return nil
  function fixture.assert_selection(session, node, purpose)
    local value = fixture.await(session.state:inspect_selection())
    t.assert_eq(node and 1 or 0, value.subtree_roots:len())
    if node then
      t.assert_eq(node, value.subtree_roots:get(1))
    end
    t.assert_eq(purpose, session.state:status().selection_purpose)
  end

  ---Waits until the view of `widget` shows `count` selected roots in `mode`, which is nil without a selection.
  ---@param widget                      era.m.explorer.Widget
  ---@param mode                        ?string
  ---@param count                       integer
  ---@return nil
  function fixture.selected(widget, mode, count)
    local session, view = widget:context()
    t.wait_until(function()
      local frame = view:frame()
      return session.state:native():applicable(frame)
        and session:mode(frame) == mode
        and frame:header().summary.known_roots == count
    end, 10000, "unexpected selection after a keypress")
  end

  ---Runs `interject` once inside Explorer's await, right after the first reply whose kind is one of `kinds`. The
  ---awaiting operation resumes when `interject` returns, so awaiting in it holds the operation at that reply.
  ---@param kinds                       string[]
  ---@param interject                   async fun(reply: table): nil
  ---@return fun() restore
  function fixture.interject(kinds, interject)
    local Session = require("era.m.explorer.session")
    local await = Session.await
    local done = false
    return t:patch_table(Session, "await", function(future)
      local reply = await(future)
      if not done and type(reply) == "table" and vim.list_contains(kinds, reply.kind) then
        done = true
        interject(reply)
      end
      return reply
    end)
  end

  ---Records, instead of offering them, the paths Copy Path offers for the rest of the case; `filepaths` holds the
  ---latest.
  ---@return { filepaths: string[]|nil }
  function fixture.record_copy()
    local copied = {}
    t:patch_table(era.fn, "select_copy_filepaths", function(options)
      copied.filepaths = options.filepaths
    end)
    return copied
  end

  ---Loads the buffer of the file `path`, deleted when the case ends, and replaces its text with `lines` when given,
  ---leaving it modified.
  ---@param path                        string
  ---@param lines                       ?string[]
  ---@return integer
  function fixture.load_buffer(path, lines)
    local bufnr = vim.fn.bufadd(path)
    t:defer(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)
    vim.fn.bufload(bufnr)
    if lines then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
    return bufnr
  end

  ---Deletes, when the case ends, every buffer then named under the directory `path`.
  ---@param path                        string
  ---@return nil
  function fixture.discard_buffers(path)
    t:defer(function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(bufnr):sub(1, #path + 1) == path .. "/" then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end)
  end

  ---A scratch buffer named `path` with a diagnostic namespace of its own, both released when the case ends.
  ---@param path                        string
  ---@return integer bufnr
  ---@return integer namespace
  function fixture.diagnostic_buffer(path)
    local bufnr = t:buffer(nil, { name = path })
    local namespace = vim.api.nvim_create_namespace("explorer-diagnostics-" .. bufnr)
    t:defer(function()
      vim.diagnostic.reset(namespace)
    end)
    return bufnr, namespace
  end

  fixture.messages = messages
  fixture.infos = infos
  return fixture
end

return M
