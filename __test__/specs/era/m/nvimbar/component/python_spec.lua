local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local CancellationToken = require("stl.c.cancellation_token")
local Component = require("era.m.nvimbar.component")
local t = harness.new("era.m.nvimbar.component.python")

local venv = "/venvs/first"
bootstrap.with_runtime(t, {
  stl = {
    reporter = { error = function() end },
    nvim = {
      fn = {
        txt = function(text)
          return text
        end,
        btn = function(text, _callback, _args)
          return text
        end,
      },
    },
  },
  dot = {
    G = {
      register_anonymous_fn = function()
        return "select_python"
      end,
    },
    context = {
      lsp = {
        python_venv_path = {
          snapshot = function()
            return venv
          end,
        },
        get_python_bin_path = function()
          return venv .. "/bin/python"
        end,
      },
    },
  },
  yoz = { path = {
    basename = function(path)
      return path:match("[^/]+$")
    end,
  } },
})

local python = require("era.m.nvimbar.component.python")

local function processes()
  local jobs = {}
  t:patch_table(vim, "system", function(command, opts, callback)
    local job = { command = command, callback = callback, killed = false }
    t.assert_true(opts.text)
    jobs[#jobs + 1] = job
    return {
      kill = function(_, signal)
        t.assert_eq(15, signal)
        job.killed = true
      end,
    }
  end)
  return jobs
end

t:test("Python version requests return a pending Future without waiting for a process", function()
  local jobs = processes()
  local token = CancellationToken.new()
  t:defer(function()
    token:cancel()
  end)
  venv = "/venvs/first"
  local result = python.env("f_sl").refresh({ filetype = "python" }, token)
  t.assert_false(result:is_done())
  t.assert_true(vim.deep_equal({ "/venvs/first/bin/python", "--version" }, jobs[1].command))
  jobs[1].callback({ code = 0, stdout = "Python 3.14.0\n" })
  t.wait_until(function()
    return result:is_done()
  end, 1000)
  t.assert_eq("3.14.0 (first)  ", result:get_result().text)
  token:cancel()
  t.assert_false(jobs[1].killed, "completed processes are not killed")
end)

t:test("cancellation stops only its own process and ignores late output", function()
  local jobs = processes()
  local first_token, second_token = CancellationToken.new(), CancellationToken.new()
  t:defer(function()
    first_token:cancel()
    second_token:cancel()
  end)
  local component = python.env("f_sl")
  venv = "/venvs/first"
  local first = component.refresh({ filetype = "python" }, first_token)
  venv = "/venvs/second"
  local second = component.refresh({ filetype = "python" }, second_token)
  first_token:cancel()
  t.assert_true(jobs[1].killed)
  t.assert_false(jobs[2].killed)
  jobs[2].callback({ code = 0, stdout = "Python 3.14.1\n" })
  jobs[1].callback({ code = 0, stdout = "Python 3.12.0\n" })
  t.wait_until(function()
    return second:is_done()
  end, 1000)
  t.assert_true(first:is_failed())
  t.assert_eq("3.14.1 (second)  ", second:get_result().text)

  venv = "/venvs/first"
  local retry = component.refresh({ filetype = "python" }, second_token)
  t.assert_eq(3, #jobs, "cancelled output cannot populate the version cache")
  jobs[3].callback({ code = 0, stdout = "Python 3.13.0\n" })
  t.wait_until(function()
    return retry:is_done()
  end, 1000)
  jobs[1].callback({ code = 0, stdout = "Python 3.12.0\n" })
  local drained = false
  vim.schedule(function()
    drained = true
  end)
  t.wait_until(function()
    return drained
  end, 1000)
  t.assert_eq("3.13.0 (first)  ", component.refresh({ filetype = "python" }, second_token).text)
end)

t:test("one interpreter probe serves repeated buffer and window switches", function()
  local jobs = processes()
  venv = "/venvs/first"
  local component = Component.new(python.env("f_sl"), function() end, function()
    return true
  end)
  t:defer(function()
    component:dispose()
  end)
  for index = 1, 11 do
    local bufnr = index % 2 + 1
    local context = {
      winnr = index % 3 + 1,
      bufnr = bufnr,
      tabnr = 1,
      filepath = "/project/" .. bufnr .. ".py",
      cwd = "/project",
      filetype = "python",
    }
    local probes = #jobs
    component:request(context)
    t.wait_until(function()
      return component.status == "ready" or #jobs > probes
    end, 1000)
    if #jobs > probes then
      jobs[#jobs].callback({ code = 0, stdout = "Python 3.14.0\n" })
    end
    t.wait_until(function()
      return component.status == "ready"
    end, 1000)
    t.assert_eq(context, component.snapshot.context, "UI snapshots retain the requesting scope")
    t.assert_eq("3.14.0 (first)  ", component.snapshot.data.text)
  end
  t.assert_eq(1, #jobs, "buffer and window changes do not reprobe the same interpreter")
end)

t:test("dirty events during a Python probe reuse its result and still detect a new environment", function()
  local jobs = processes()
  venv = "/venvs/first"
  local component = Component.new(python.env("f_sl"), function() end, function()
    return true
  end)
  t:defer(function()
    component:dispose()
  end)
  local context = {
    winnr = 1,
    bufnr = 1,
    tabnr = 1,
    filepath = "/project/test.py",
    cwd = "/project",
    filetype = "python",
  }
  component:request(context)
  t.wait_until(function()
    return #jobs == 1
  end, 1000)
  for _ = 1, 20 do
    component:request(context)
  end
  jobs[1].callback({ code = 0, stdout = "Python 3.14.0\n" })
  t.wait_until(function()
    return component.status == "ready"
  end, 1000)
  t.assert_eq(1, #jobs)
  t.assert_eq(1, component.running_version, "equivalent requests do not reacquire the cached version either")
  t.assert_eq("3.14.0 (first)  ", component.snapshot.data.text)

  venv = "/venvs/second"
  component:request(context)
  t.wait_until(function()
    return #jobs == 2
  end, 1000)
  venv = "/venvs/third"
  component:request(context)
  jobs[2].callback({ code = 0, stdout = "Python 3.14.1\n" })
  t.wait_until(function()
    return #jobs == 3
  end, 1000)
  t.assert_eq("3.14.0 (first)  ", component.snapshot.data.text, "an obsolete environment is never published")
  jobs[3].callback({ code = 0, stdout = "Python 3.14.2\n" })
  t.wait_until(function()
    return component.status == "ready"
  end, 1000)
  t.assert_eq("3.14.2 (third)  ", component.snapshot.data.text)
  component:request(context)
  t.assert_eq("ready", component.status)
  t.assert_eq(3, #jobs)
end)

t:test("versions are cached by interpreter while labels use the current environment", function()
  local jobs = processes()
  local token = CancellationToken.new()
  t:defer(function()
    token:cancel()
  end)
  local component = python.env("f_sl")
  for index, name in ipairs({ "first", "second" }) do
    venv = "/venvs/" .. name
    local result = component.refresh({ filetype = "python" }, token)
    jobs[index].callback({ code = 0, stdout = "Python 3.14." .. index .. "\n" })
    t.wait_until(function()
      return result:is_done()
    end, 1000)
  end
  venv = "/venvs/first"
  t.assert_eq("3.14.1 (first)  ", component.refresh({ filetype = "python" }, token).text)
  t:patch_table(dot.context.lsp, "get_python_bin_path", function()
    return "/venvs/first/bin/python"
  end)
  venv = "/aliases/current"
  t.assert_eq("3.14.1 (current)  ", component.refresh({ filetype = "python" }, token).text)
  t.assert_eq(2, #jobs)
end)

t:test("failed and unparseable versions remain retryable through the runtime", function()
  for _, output in ipairs({
    { code = 1, stdout = "Python 9.9.9\n", stderr = "probe failed" },
    { code = 0, stdout = "unrecognized version\n" },
  }) do
    local jobs = processes()
    local component = Component.new(python.env("f_sl"), function() end, function()
      return true
    end)
    t:defer(function()
      component:dispose()
    end)
    venv = "/venvs/first"
    local context = { winnr = 1, bufnr = 1, tabnr = 1, filepath = "/first.py", cwd = "/", filetype = "python" }
    component:request(context)
    t.wait_until(function()
      return #jobs == 1
    end, 1000)
    jobs[1].callback(output)
    t.wait_until(function()
      return component.status == "ready" or component.status == "failed"
    end, 1000)
    t.assert_eq("failed", component.status, "invalid output cannot become a reusable snapshot")
    component:request(context)
    t.wait_until(function()
      return #jobs == 2
    end, 1000)
    jobs[2].callback({ code = 0, stdout = "Python 3.14.0\n" })
    t.wait_until(function()
      return component.status == "ready"
    end, 1000)
    t.assert_eq("3.14.0 (first)  ", component.snapshot.data.text)
    component:request(context)
    t.assert_eq("ready", component.status)
    t.assert_eq(2, #jobs, "a successful parsed version is reusable")
  end
end)

t:test("timed-out output cannot satisfy a retry or populate the cache", function()
  local jobs = processes()
  local definition = python.env("f_sl")
  definition.timeout = 10
  local component = Component.new(definition, function() end, function()
    return true
  end)
  t:defer(function()
    component:dispose()
  end)
  venv = "/venvs/first"
  local context = { winnr = 1, bufnr = 1, tabnr = 1, filepath = "/first.py", cwd = "/", filetype = "python" }
  component:request(context)
  t.wait_until(function()
    return component.status == "failed"
  end, 1000)
  t.assert_true(jobs[1].killed)
  jobs[1].callback({ code = 0, stdout = "Python 9.9.9\n" })
  definition.timeout = 1000
  component:request(context)
  t.wait_until(function()
    return #jobs == 2 or component.status == "ready"
  end, 1000)
  t.assert_eq(2, #jobs, "timeout must cause a fresh probe")
  jobs[2].callback({ code = 0, stdout = "Python 3.14.0\n" })
  t.wait_until(function()
    return component.status == "ready"
  end, 1000)
  t.assert_eq("3.14.0 (first)  ", component.snapshot.data.text)
end)

t:test("spawn failures reject the refresh", function()
  t:patch_table(vim, "system", function()
    error("cannot spawn Python")
  end)
  local token = CancellationToken.new()
  t:defer(function()
    token:cancel()
  end)
  local result = python.env("f_sl").refresh({ filetype = "python" }, token)
  t.assert_true(result:is_failed())
  t.assert_true(result:get_error():find("cannot spawn Python", 1, true) ~= nil)
end)

t:run()
