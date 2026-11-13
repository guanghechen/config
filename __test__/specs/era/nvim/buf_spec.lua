local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local harness = require("__test__.support.harness")

local t = harness.new()

t:test("tab-local close deletes only requested unreferenced buffers", function()
  local requested_bufnr = 41
  local unrelated_bufnr = 42
  local candidates = nil ---@type integer[]|nil
  local deleted = {} ---@type integer[]

  t:patch_global("stl", {
    nvim = {
      buf = {
        has_unsaved_changes = function()
          return false
        end,
      },
      tab = {
        list_visible_bufnrs = function()
          return {}
        end,
      },
    },
  })
  t:patch_global("dot", {
    tab = {
      resolve = function()
        return {
          bufs = {
            { bufnr = requested_bufnr, pinned = false },
          },
        }
      end,
      on_bufs_close = function() end,
      retrieve_unreferenced_bufnrs = function(bufnrs)
        candidates = bufnrs
        return bufnrs or { requested_bufnr, unrelated_bufnr }
      end,
    },
  })
  t:patch_table(vim.api, "nvim_buf_delete", function(bufnr)
    deleted[#deleted + 1] = bufnr
  end)

  local Buf = assert(loadfile("lua/era/nvim/buf.lua"))()
  Buf.close_others()

  t.assert_eq(1, #assert(candidates), "candidate count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(requested_bufnr, candidates[1], "candidate buffer")
  t.assert_eq(1, #deleted, "deleted buffer count")
  t.assert_eq(requested_bufnr, deleted[1], "deleted buffer")
end)

---Stubs the tab, path and reporter collaborators of `era.nvim.buf` around buffers named "/work/<bufnr>.lua".
---@param unsaved_bufnr                 integer
---@param tab                           table
---@return table[] warnings
local function stub_close(unsaved_bufnr, tab)
  t:patch_global("stl", {
    nvim = {
      buf = {
        has_unsaved_changes = function(bufnr)
          return bufnr == unsaved_bufnr
        end,
      },
      tab = {
        list_visible_bufnrs = function()
          return {}
        end,
      },
    },
  })
  local warnings = bootstrap.with_reporter(t).warn
  t:patch_global("dot", {
    path = {
      cwd = function()
        return "/work"
      end,
      relative = function(_, filepath)
        return (filepath:gsub("^/work/", ""))
      end,
    },
    tab = tab,
    win = {
      resolve = function()
        return { history = {} }
      end,
    },
  })
  t:patch_table(vim.api, "nvim_buf_get_name", function(bufnr)
    return "/work/" .. bufnr .. ".lua"
  end)
  return warnings
end

t:test("tab-local close keeps buffers with unsaved changes in the tab and reports them", function()
  local saved_bufnr, unsaved_bufnr = 61, 62
  local closed = nil ---@type integer[]|nil
  local deleted = {} ---@type integer[]
  local warnings = stub_close(unsaved_bufnr, {
    resolve = function()
      return { bufs = { { bufnr = saved_bufnr, pinned = false }, { bufnr = unsaved_bufnr, pinned = false } } }
    end,
    on_bufs_close = function(_, bufnrs)
      closed = bufnrs
    end,
    retrieve_unreferenced_bufnrs = function(bufnrs)
      return bufnrs
    end,
  })
  t:patch_table(vim.api, "nvim_buf_delete", function(bufnr)
    deleted[#deleted + 1] = bufnr
  end)

  local Buf = assert(loadfile("lua/era/nvim/buf.lua"))()
  Buf.close_others()

  t.assert_same({ saved_bufnr }, closed, "buffers taken off the tab")
  t.assert_same({ saved_bufnr }, deleted, "deleted buffers")
  t.assert_same({ "Kept buffers with unsaved changes: 62.lua" }, bootstrap.messages(warnings), "report")
end)

t:test("close stays on a source buffer with unsaved changes", function()
  local unsaved_bufnr = 71
  local switched = false ---@type boolean
  local deleted = {} ---@type integer[]
  local warnings = stub_close(unsaved_bufnr, {
    retrieve_winnr_sourcefile = function()
      return 1000
    end,
  })
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return unsaved_bufnr
  end)
  t:patch_table(vim.api, "nvim_win_set_buf", function()
    switched = true
  end)
  t:patch_table(vim.api, "nvim_buf_delete", function(bufnr)
    deleted[#deleted + 1] = bufnr
  end)

  local Buf = assert(loadfile("lua/era/nvim/buf.lua"))()
  Buf.close()

  t.assert_false(switched, "the window keeps the buffer")
  t.assert_same({}, deleted, "deleted buffers")
  t.assert_same({ "Kept buffers with unsaved changes: 71.lua" }, bootstrap.messages(warnings), "report")
end)

---@class era.nvim.buf.test.ISavePrompts
---@field reports                       table<string, table[]>
---@field inputs                        { default: string, answer: fun(text: string|nil) }[]
---@field selects                       (fun(choice: string|nil))[]

---Stubs the path, window and status collaborators of `era.nvim.buf.save` for files in `dir`, over the native `yoz`, and
---records its reports and the prompts it opens, in order, each with the function that answers it.
---@param dir                           string
---@return era.nvim.buf.test.ISavePrompts
local function stub_save(dir)
  bootstrap.with_native(t)
  t:patch_global("dot", {
    path = {
      cwd = function()
        return dir
      end,
      workspace = function()
        return dir
      end,
      relative = function(from, to, sep)
        return yoz.path.relative(from, to, false, sep)
      end,
      resolve = function(cwd, to)
        return yoz.path.resolve(cwd, to, true, "/")
      end,
    },
    state = {
      status = {
        dirty_winline_nr = { next = function() end },
        dirtier_statusline = { mark_dirty = function() end },
        dirtier_tabline = { mark_dirty = function() end },
      },
    },
    tab = {
      retrieve_winnr_sourcefile = function()
        return vim.api.nvim_get_current_win()
      end,
    },
  })
  local prompts = { reports = bootstrap.with_reporter(t), inputs = {}, selects = {} } ---@type era.nvim.buf.test.ISavePrompts
  t:patch_table(vim.ui, "input", function(opts, on_confirm)
    prompts.inputs[#prompts.inputs + 1] = { default = opts.default, answer = on_confirm }
  end)
  t:patch_table(vim.ui, "select", function(_, _, on_choice)
    prompts.selects[#prompts.selects + 1] = on_choice
  end)
  return prompts
end

---A buffer read from the file at `path`, with `lines` in place of what the file holds.
---@param path                          string
---@param lines                         string[]
---@return integer
local function edit_file(path, lines)
  local bufnr = vim.fn.bufadd(path) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.fn.bufload(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  return bufnr
end

---The bytes of `path`, or nil without the file.
---@param path                          string
---@return string|nil
local function read(path)
  return vim.uv.fs_stat(path) ~= nil and fs.read(path) or nil
end

t:test("save writes the files on disk at once and asks for each new file only after the one before", function()
  local dir = t:tempdir()
  local prompts = stub_save(dir)
  fs.write(dir .. "/a.txt", "old\n")
  local bufnrs = {
    edit_file(dir .. "/a.txt", { "new" }),
    t:buffer({ "one" }, { name = dir .. "/one.txt", listed = true }),
    t:buffer({ "two" }, { name = dir .. "/two.txt", listed = true }),
  }

  assert(loadfile("lua/era/nvim/buf.lua"))().save()
  t.assert_eq("new\n", read(dir .. "/a.txt"), "written before any prompt is answered")
  t.assert_eq(1, #prompts.inputs, "one prompt open")

  prompts.inputs[1].answer(prompts.inputs[1].default)
  t.drain()
  t.assert_eq("one\n", read(dir .. "/one.txt"), "first new file")
  t.assert_eq(2, #prompts.inputs, "the next prompt opens once the first is answered")
  t.assert_eq("two.txt", prompts.inputs[2].default, "next default")

  prompts.inputs[2].answer(prompts.inputs[2].default)
  t.drain()
  t.assert_eq("two\n", read(dir .. "/two.txt"), "second new file")
  for _, bufnr in ipairs(bufnrs) do
    t.assert_false(vim.api.nvim_get_option_value("modified", { buf = bufnr }), "saved " .. bufnr)
  end
  t.assert_same({}, prompts.reports.warn, "no report")
end)

t:test("a cancelled prompt leaves only its own file unsaved, and reports it", function()
  local dir = t:tempdir()
  local prompts = stub_save(dir)
  fs.write(dir .. "/a.txt", "old\n")
  edit_file(dir .. "/a.txt", { "new" })
  local cancelled = t:buffer({ "one" }, { name = dir .. "/one.txt", listed = true })
  t:buffer({ "two" }, { name = dir .. "/two.txt", listed = true })

  assert(loadfile("lua/era/nvim/buf.lua"))().save()
  prompts.inputs[1].answer(nil)
  t.drain()
  prompts.inputs[2].answer("two.txt")
  t.drain()

  t.assert_eq("new\n", read(dir .. "/a.txt"), "file on disk")
  t.assert_eq("two\n", read(dir .. "/two.txt"), "the other new file")
  t.assert_nil(read(dir .. "/one.txt"), "cancelled file")
  t.assert_true(vim.api.nvim_get_option_value("modified", { buf = cancelled }), "still modified")
  t.assert_same({ "Not saved: one.txt (cancelled)" }, bootstrap.messages(prompts.reports.warn))
end)

t:test("a folder path or a declined overwrite leaves the file unsaved, and a confirmed one writes over", function()
  local dir = t:tempdir()
  local prompts = stub_save(dir)
  vim.fn.mkdir(dir .. "/folder", "p")
  fs.write(dir .. "/kept.txt", "kept\n")
  fs.write(dir .. "/over.txt", "over\n")
  t:buffer({ "one" }, { name = dir .. "/one.txt", listed = true })
  t:buffer({ "two" }, { name = dir .. "/two.txt", listed = true })
  t:buffer({ "three" }, { name = dir .. "/three.txt", listed = true })

  assert(loadfile("lua/era/nvim/buf.lua"))().save()
  prompts.inputs[1].answer("folder")
  t.drain()
  prompts.inputs[2].answer("kept.txt")
  prompts.selects[1]("No")
  t.drain()
  prompts.inputs[3].answer("over.txt")
  prompts.selects[2]("Yes")
  t.drain()

  t.assert_nil(read(dir .. "/one.txt"), "not written under its own name either")
  t.assert_eq("kept\n", read(dir .. "/kept.txt"), "declined")
  t.assert_eq("three\n", read(dir .. "/over.txt"), "written over")
  t.assert_same(
    { "Not saved: one.txt (folder is a directory), two.txt (not overwritten)" },
    bootstrap.messages(prompts.reports.warn)
  )
end)

t:test("a file that fails to write leaves the others to be written, and reports why", function()
  local dir = t:tempdir()
  local prompts = stub_save(dir)
  -- A file read without write permission is 'readonly', which `:write` refuses.
  fs.write(dir .. "/locked.txt", "locked\n")
  vim.uv.fs_chmod(dir .. "/locked.txt", tonumber("444", 8))
  edit_file(dir .. "/locked.txt", { "changed" })
  fs.write(dir .. "/a.txt", "old\n")
  edit_file(dir .. "/a.txt", { "new" })
  t:buffer({ "one" }, { name = dir .. "/one.txt", listed = true })

  assert(loadfile("lua/era/nvim/buf.lua"))().save()
  -- Another buffer holds the name, so the new file cannot take it.
  prompts.inputs[1].answer("a.txt")
  prompts.selects[1]("Yes")
  t.drain()

  t.assert_eq("locked\n", read(dir .. "/locked.txt"), "refused")
  t.assert_eq("new\n", read(dir .. "/a.txt"), "the next file on disk")
  t.assert_same({
    "Not saved: locked.txt (E45: 'readonly' option is set (add ! to override)), "
      .. "one.txt (E95: Buffer with this name already exists)",
  }, bootstrap.messages(prompts.reports.warn))
end)

t:test("a file saved or closed while a prompt is open is no longer asked about", function()
  local dir = t:tempdir()
  local prompts = stub_save(dir)
  local one = t:buffer({ "one" }, { name = dir .. "/one.txt", listed = true })
  local two = t:buffer({ "two" }, { name = dir .. "/two.txt", listed = true })
  local three = t:buffer({ "three" }, { name = dir .. "/three.txt", listed = true })

  assert(loadfile("lua/era/nvim/buf.lua"))().save()
  -- Another save writes the first two files while the first prompt is open, and the third buffer is closed.
  for _, bufnr in ipairs({ one, two }) do
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("write")
    end)
  end
  vim.api.nvim_buf_delete(three, { force = true })
  prompts.inputs[1].answer("other.txt")
  -- Each skipped file hands over to the next one on a later tick.
  for _ = 1, 3 do
    t.drain()
  end

  t.assert_nil(read(dir .. "/other.txt"), "the answer for a saved file is not taken")
  t.assert_eq(1, #prompts.inputs, "no prompt for the files no longer pending")
  t.assert_same({}, prompts.reports.warn, "nothing reported unsaved")
end)

t:test("a write hook that fails after the file is written is reported as an error, not as unsaved", function()
  local dir = t:tempdir()
  local prompts = stub_save(dir)
  fs.write(dir .. "/a.txt", "old\n")
  local bufnr = edit_file(dir .. "/a.txt", { "new" })
  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = bufnr,
    callback = function()
      error("post hook failed")
    end,
  })

  assert(loadfile("lua/era/nvim/buf.lua"))().save()

  t.assert_eq("new\n", read(dir .. "/a.txt"), "written")
  t.assert_same({}, prompts.reports.warn, "not reported unsaved")
  t.assert_eq(1, #prompts.reports.error, "one error")
  local message = prompts.reports.error[1].message ---@type string
  t.assert_true(message:find("post hook failed", 1, true) ~= nil and not message:find("\n", 1, true), message)
end)

t:run()
