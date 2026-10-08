---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.full_config" ---@type string

local here = vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))
local harness = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here)))
local root = vim.env.NVIM_EXPLORER_BENCH_CHECKOUT or harness
local Metrics = assert(loadfile(here .. "/metrics.lua"))()
package.path = harness .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local samples, moves = tonumber(arg[1]) or 3, tonumber(arg[2]) or 100
assert(samples >= 1 and samples <= 100 and samples % 1 == 0)
assert(moves >= 10 and moves <= 1000 and moves % 1 == 0)
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local results = {}
local directory, ui

---@param predicate                     fun(): boolean
---@param message                       string
---@return nil
local function until_(predicate, message)
  local deadline = vim.uv.hrtime() + 15000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message)
    vim.wait(5, function()
      return false
    end, 5)
  end
end

local ok, error = xpcall(function()
  for sample = 1, samples do
    directory = vim.fn.tempname()
    assert(vim.uv.fs_mkdir(directory, 448))
    directory = assert(vim.uv.fs_realpath(directory))
    assert(vim.uv.fs_mkdir(directory .. "/files", 448))
    assert(vim.uv.fs_mkdir(directory .. "/state", 448))
    for index = 1, 200 do
      vim.fn.writefile({ "fixture" }, string.format("%s/files/file-%03d.txt", directory, index))
    end
    ui = UI.new({
      timeout_ms = 30000,
      init = root .. "/init.lua",
      args = {
        "--cmd",
        string.format("lua vim.g.explorer_test_root=%q; vim.g.explorer_test_directory=%q", root, directory),
        "--cmd",
        "lua dofile("
          .. string.format("%q", harness .. "/__test__/fixtures/era/m/explorer/full_config_init.lua")
          .. ")",
      },
    })
    local grid = Grid.new(ui)
    ui:rpc("nvim_ui_attach", 110, 40, { rgb = true, ext_linegrid = true })
    vim.wait(1500, function()
      return false
    end, 20)
    local result = { sample = sample, operations = {} }
    ui:rpc(
      "nvim_exec_lua",
      [[
      local directory = ...
      acceptance = { directory = directory, errors = {}, refreshes = 0 }
      vim.v.errmsg = ""
      local report = stl.reporter.error
      stl.reporter.error = function(value)
        acceptance.errors[#acceptance.errors + 1] = vim.inspect(value)
        report(value)
      end
      vim.cmd.edit(directory .. "/files/file-001.txt")
      acceptance.source_winnr = vim.api.nvim_get_current_win()
      era.widget.explorer.focus()
      acceptance.widget = era.widget.explorer.get_widget()
      assert(vim.wait(10000, function()
        local view = acceptance.widget._views[vim.api.nvim_get_current_tabpage()]
        return view and view:frame() and view:frame():header().row_count == 200
      end, 1))
      acceptance.session, acceptance.view = acceptance.widget:context()
      assert(vim.ui.input == require("era.m.input").open)
      assert(not dot.context.behavior.auto_im:snapshot())
    ]],
      { directory }
    )

    for _, operation in ipairs({ "create", "rename", "delete" }) do
      ui:rpc(
        "nvim_exec_lua",
        [[
        acceptance.widget:focus()
        vim.cmd.stopinsert()
      ]],
        {}
      )
      if operation ~= "create" then
        local target = directory .. "/files/" .. (operation == "rename" and "created.txt" or "renamed.txt")
        until_(function()
          return ui:rpc(
            "nvim_exec_lua",
            [[
            local target = ...
            local a = acceptance
            local frame = a.view:frame()
            return a.widget:get_cursor_filepath() == target and frame
              and frame:header().cursor_row == vim.api.nvim_win_get_cursor(a.view.winnr)[1]
          ]],
            { target }
          )
        end, "Explorer did not reveal the next mutation target")
      end
      local started = vim.uv.hrtime()
      ui:rpc("nvim_input", operation == "create" and "a" or operation == "rename" and "r" or "d")
      local prompt = operation == "create" and "Create file"
        or operation == "rename" and "Rename to"
        or 'Permanently delete "renamed.txt"?'
      until_(function()
        return grid:find(prompt) ~= nil
      end, "prompt did not open: " .. operation)
      local prompt_ms = (vim.uv.hrtime() - started) / 1000000
      if operation ~= "delete" then
        ui:rpc(
          "nvim_exec_lua",
          [[
          local name = ...
          local bufnr = vim.api.nvim_get_current_buf()
          assert(vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "prompt")
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { name })
          vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { 1, #name })
        ]],
          { operation == "create" and "created.txt" or "renamed.txt" }
        )
      end
      started = vim.uv.hrtime()
      ui:rpc("nvim_input", operation == "delete" and "y" or "<CR>")
      until_(function()
        return ui:rpc(
          "nvim_exec_lua",
          [[
          local operation = ...
          local a = acceptance
          local path = a.directory .. "/files/"
          local frame = a.view:frame()
          if a.session:busy() or not frame or a.view._busy then return false end
          if frame:header().row_count ~= (operation == "delete" and 200 or 201) then return false end
          local name = operation == "create" and "created.txt" or "renamed.txt"
          local displayed = false
          for _, line in ipairs(vim.api.nvim_buf_get_lines(a.view.bufnr, 0, -1, false)) do
            if line:find(name, 1, true) then displayed = true; break end
          end
          if displayed ~= (operation ~= "delete") then return false end
          if operation == "create" then
            return vim.uv.fs_stat(path .. "created.txt") ~= nil
              and vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) == path .. "created.txt"
          elseif operation == "rename" then
            return vim.uv.fs_stat(path .. "created.txt") == nil and vim.uv.fs_stat(path .. "renamed.txt") ~= nil
              and vim.api.nvim_buf_get_name(a.created_bufnr) == path .. "renamed.txt"
          end
          return vim.uv.fs_stat(path .. "renamed.txt") == nil
        ]],
          { operation }
        )
      end, "operation did not complete: " .. operation)
      result.operations[#result.operations + 1] = {
        kind = operation,
        prompt_ms = prompt_ms,
        confirmed_ms = (vim.uv.hrtime() - started) / 1000000,
      }
      io.stderr:write("Completed ", operation, " in sample ", sample, "\n")
      if operation == "create" then
        ui:rpc(
          "nvim_exec_lua",
          [[
          acceptance.created_bufnr = vim.api.nvim_get_current_buf()
          vim.api.nvim_buf_set_lines(acceptance.created_bufnr, 0, -1, false, { "unsaved fixture" })
        ]],
          {}
        )
      else
        assert(
          ui:rpc(
            "nvim_exec_lua",
            [[
          local bufnr = acceptance.created_bufnr
          return vim.api.nvim_buf_is_valid(bufnr)
            and vim.api.nvim_get_option_value("modified", { buf = bufnr })
            and vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1] == "unsaved fixture"
        ]],
            {}
          ),
          "mutation lost unsaved buffer contents"
        )
      end
    end

    ui:rpc(
      "nvim_exec_lua",
      [[
      local a = acceptance
      a.widget:focus()
      vim.cmd.stopinsert()
      assert(vim.wait(10000, function() return a.view:frame():header().row_count == 200 end, 1))
      local reset = a.view:set_cursor(1)
      assert(vim.wait(10000, function()
        return reset:is_done() and a.view:frame():header().cursor_row == 1
          and vim.api.nvim_win_get_cursor(a.view.winnr)[1] == 1
      end, 1))
      a.refresh_timer = assert(vim.uv.new_timer())
      a.refresh_timer:start(20, 40, vim.schedule_wrap(function()
        if not a.refreshing or a.refreshing:is_done() then
          a.refreshes = a.refreshes + 1
          a.refreshing = a.widget:refresh()
        end
      end))
    ]],
      {}
    )
    local worst = 0
    for step = 1, moves do
      local offset = (step - 1) % 20
      local row = offset < 10 and offset + 2 or 20 - offset
      local started = vim.uv.hrtime()
      ui:rpc("nvim_input", offset < 10 and "j" or "k")
      until_(function()
        return ui:rpc(
          "nvim_exec_lua",
          [[
          local row = ...
          local view = acceptance.view
          return vim.api.nvim_win_get_cursor(view.winnr)[1] == row and view:frame():header().cursor_row == row
        ]],
          { row }
        )
      end, string.format("cursor did not reach row %d at step %d in sample %d", row, step, sample))
      worst = math.max(worst, (vim.uv.hrtime() - started) / 1000000)
    end
    local summary = ui:rpc(
      "nvim_exec_lua",
      [[
      local a = acceptance
      a.refresh_timer:stop(); a.refresh_timer:close()
      if a.refreshing then assert(vim.wait(10000, function() return a.refreshing:is_done() end, 1)) end
      a.widget:dispose()
      vim.wait(150, function() return false end, 5)
      return {
        refreshes = a.refreshes,
        errors = a.errors,
        errmsg = vim.v.errmsg,
        messages = vim.api.nvim_exec2("messages", {output=true}).output,
      }
    ]],
      {}
    )
    assert(#summary.errors == 0, vim.inspect(summary.errors))
    assert(summary.errmsg == "", summary.errmsg)
    result.cursor_moves, result.cursor_worst_ms, result.refreshes = moves, worst, summary.refreshes
    result.messages = summary.messages
    results[#results + 1] = result
    ui:close()
    ui = nil
    vim.fn.delete(directory, "rf")
    directory = nil
    io.stderr:write("Completed full-config sample ", sample, "\n")
  end
end, debug.traceback)
if not ok and ui then
  local diagnostic_ok, diagnostic = pcall(
    ui.rpc,
    ui,
    "nvim_exec_lua",
    [[
    local a = acceptance
    if not a then return {} end
    local view = a.view
    return vim.inspect({
      current_winnr = vim.api.nvim_get_current_win(),
      mode = vim.api.nvim_get_mode(),
      explorer_winnr = view and view.winnr,
      cursor = view and vim.api.nvim_win_is_valid(view.winnr) and vim.api.nvim_win_get_cursor(view.winnr),
      frame = view and view:frame() and view:frame():header(),
      state = a.session and a.session.state:status(),
      errors = a.errors,
      refreshes = a.refreshes,
    })
  ]],
    {}
  )
  io.stderr:write("Failure state: ", vim.inspect(diagnostic_ok and diagnostic or tostring(diagnostic)), "\n")
end
if ui then
  ui:close()
end
if directory then
  vim.fn.delete(directory, "rf")
end
assert(ok, error)
io.stdout:write(
  vim.json.encode({
    samples = results,
    nvim = vim.version(),
    memory_measurement = Metrics.memory_description(),
    conditions = "Full init.lua, plugins and UI dressing; 200 text files in an owned temporary fixture; isolated context persistence; automatic input-method changes disabled. Prompt timing ends at observed UI text. Confirmation timing includes filesystem/buffer effects and published Explorer content, not a UI flush. Real create/rename/delete UI, unsaved-buffer preservation and typed cursor motion during repeated refresh. Parent RPC observation included in timings.",
  }),
  "\n"
)
