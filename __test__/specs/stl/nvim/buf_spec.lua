local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_global(t, "stl", {
  env = { IS_WIN = false },
})
bootstrap.with_global(t, "yoz", {
  path = {
    normalize = function()
      error("POSIX buffer paths must not use Windows-aware normalization")
    end,
  },
})

local buf = assert(loadfile("lua/stl/nvim/buf.lua"))()

---A buffer as `t:buffer` creates it, whose cached filepath is dropped before the case deletes it.
---@param lines                         ?string[]
---@param options                       ?__test__.support.harness.IBufferOptions
---@return integer
local function create_buffer(lines, options)
  local bufnr = t:buffer(lines, options)
  t:defer(function()
    buf.on_buf_close(bufnr)
  end)
  return bufnr
end

---Makes the buffer module treat paths as Windows paths until the case ends.
---@return nil
local function as_windows()
  t:patch_table(stl.env, "IS_WIN", true)
  t:patch_table(yoz.path, "normalize", function(filepath)
    return filepath:gsub("\\", "/")
  end)
end

---@param filepath                      string
---@return integer
local function create_cached_buffer(filepath)
  local bufnr = create_buffer()
  vim.api.nvim_buf_set_name(bufnr, filepath)
  buf.on_buf_open(bufnr, vim.api.nvim_buf_get_name(bufnr))
  return bufnr
end

---@param old_filepath                  string
---@param new_filepath                  string
---@return nil
local function assert_windows_case_only_rename(old_filepath, new_filepath)
  as_windows()

  local bufnr = create_buffer()
  buf.on_buf_open(bufnr, old_filepath)
  buf.on_buf_open(bufnr, new_filepath)

  local loaded_bufnrs = buf.get_loaded_bufnrs()
  t.assert_eq(bufnr, buf.lookup_bufnr(loaded_bufnrs, old_filepath), "old casing")
  t.assert_eq(bufnr, buf.lookup_bufnr(loaded_bufnrs, new_filepath), "new casing")
end

t:test("POSIX lookup keeps literal backslashes distinct from separators", function()
  local prefix = vim.fn.tempname()
  local literal = prefix .. "/back\\slash.lua"
  local nested = prefix .. "/back/slash.lua"
  local literal_bufnr = create_buffer()
  local nested_bufnr = create_buffer()
  vim.api.nvim_buf_set_name(literal_bufnr, literal)
  vim.api.nvim_buf_set_name(nested_bufnr, nested)

  t.assert_eq(literal_bufnr, buf.locate_bufnr(literal), "literal backslash buffer")
  t.assert_eq(nested_bufnr, buf.locate_bufnr(nested), "nested path buffer")
end)

t:test("POSIX lookup keeps literal environment variables distinct from expanded paths", function()
  local literal = vim.fn.tempname() .. "/$HOME/file.lua"
  local expanded = vim.fs.normalize(literal)
  t.assert_true(literal ~= expanded, "fixture must exercise environment expansion")

  local literal_bufnr = create_buffer()
  local expanded_bufnr = create_buffer()
  vim.api.nvim_buf_set_name(literal_bufnr, literal)
  vim.api.nvim_buf_set_name(expanded_bufnr, expanded)

  t.assert_eq(literal_bufnr, buf.locate_bufnr(literal), "literal environment variable buffer")
  t.assert_eq(expanded_bufnr, buf.locate_bufnr(expanded), "expanded path buffer")
end)

t:test("refreshing a renamed buffer replaces the cached filepath", function()
  local prefix = vim.fn.tempname() ---@type string
  local bufnr = create_cached_buffer(prefix .. "-old.lua")
  local old_filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  vim.api.nvim_buf_set_name(bufnr, prefix .. "-new.lua")
  -- The rename leaves an unlisted buffer holding the old name.
  for _, old_bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(old_bufnr) == old_filepath then
      t:defer(function()
        buf.on_buf_close(old_bufnr)
        if vim.api.nvim_buf_is_valid(old_bufnr) then
          vim.api.nvim_buf_delete(old_bufnr, { force = true })
        end
      end)
    end
  end
  local new_filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  buf.on_buf_open(bufnr, new_filepath)

  local loaded_bufnrs = buf.get_loaded_bufnrs()
  t.assert_nil(loaded_bufnrs[old_filepath], "old loaded filepath")
  t.assert_eq(bufnr, loaded_bufnrs[new_filepath], "new loaded filepath")
  t.assert_true(buf.locate_bufnr(old_filepath) ~= bufnr, "old filepath must not resolve to renamed buffer")
  t.assert_eq(bufnr, buf.locate_bufnr(new_filepath), "new filepath")
end)

t:test("an empty filepath clears the cached mapping", function()
  local bufnr = create_cached_buffer(vim.fn.tempname() .. ".lua")
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

  buf.on_buf_open(bufnr, "")

  t.assert_nil(buf.get_loaded_bufnrs()[filepath], "loaded filepath")
end)

t:test("Windows case-only rename preserves case-fold identity", function()
  assert_windows_case_only_rename("\\\\server\\share\\Case.lua", "\\\\server\\share\\case.lua")
end)

t:test("Windows lowercase lookup survives a case-only rename to mixed case", function()
  assert_windows_case_only_rename("\\\\server\\share\\case.lua", "\\\\server\\share\\Case.lua")
end)

t:test("refreshing a stale owner preserves a reused filepath", function()
  local renamed_bufnr = create_buffer()
  local reused_bufnr = create_buffer()
  local prefix = vim.fn.tempname() ---@type string
  local old_filepath = vim.fs.normalize(prefix .. "-old.lua", { expand_env = false })
  local new_filepath = vim.fs.normalize(prefix .. "-new.lua", { expand_env = false })

  buf.on_buf_open(renamed_bufnr, old_filepath)
  buf.on_buf_open(reused_bufnr, old_filepath)
  buf.on_buf_open(renamed_bufnr, new_filepath)

  local loaded_bufnrs = buf.get_loaded_bufnrs()
  t.assert_eq(renamed_bufnr, loaded_bufnrs[new_filepath], "renamed loaded filepath")
  t.assert_eq(reused_bufnr, loaded_bufnrs[old_filepath], "reused loaded filepath")
end)

t:test("closing a stale owner preserves a reused filepath", function()
  local stale_bufnr = create_buffer()
  local reused_bufnr = create_buffer()
  local filepath = vim.fs.normalize(vim.fn.tempname() .. ".lua", { expand_env = false })

  buf.on_buf_open(stale_bufnr, filepath)
  buf.on_buf_open(reused_bufnr, filepath)
  buf.on_buf_close(stale_bufnr)

  t.assert_eq(reused_bufnr, buf.get_loaded_bufnrs()[filepath], "reused loaded filepath")
end)

t:test("Windows case-fold owner survives another buffer rename", function()
  as_windows()

  local renamed_bufnr = create_buffer()
  local reused_bufnr = create_buffer()
  local old_filepath = "C:\\Case.lua"
  local reused_filepath = "C:\\case.lua"

  buf.on_buf_open(renamed_bufnr, old_filepath)
  buf.on_buf_open(reused_bufnr, reused_filepath)
  buf.on_buf_open(renamed_bufnr, "C:\\Renamed.lua")

  local loaded_bufnrs = buf.get_loaded_bufnrs()
  t.assert_eq(reused_bufnr, buf.lookup_bufnr(loaded_bufnrs, old_filepath), "reused case-fold filepath")
end)

---Types `keys` in a new buffer shown in the current window, then `<F2>`, mapped in `modes` to call `read`, then `after`,
---and returns what `read` returned.
---@param keys                          string
---@param modes                         string|string[]
---@param read                          fun(): any
---@param after                         string
---@return any
local function read_typed(keys, modes, read, after)
  local bufnr = create_buffer({ "abc中x", "hello world", "second line" }, { current = true })
  local value ---@type any
  vim.keymap.set(modes, "<F2>", function()
    value = read()
  end, { buffer = bufnr })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>" .. keys .. "<F2>" .. after), "x", false)
  return value
end

---@param keys                          string Keys that end in Visual mode, where the region is read.
---@return stl.nvim.buf.IVisualRegion|nil
local function visual_region(keys)
  return read_typed(keys, "x", buf.retrieve_visual_region, "<Esc>")
end

---@param expected                      table
---@param region                        stl.nvim.buf.IVisualRegion|nil
---@param msg                           string
local function assert_region(expected, region, msg)
  t.assert_same(expected, region, msg .. ": " .. vim.inspect(region))
end

t:test("a Visual region keeps whole characters and follows the Visual mode", function()
  assert_region(
    { lines = { "abc中" }, start_lnum = 1, start_col = 1, end_lnum = 1, end_col = 6 },
    visual_region("gg0v3l"),
    "a charwise selection ending on a multibyte character"
  )
  assert_region(
    { lines = { "hello world", "second line" }, start_lnum = 2, start_col = 1, end_lnum = 3, end_col = 11 },
    visual_region("2G6|Vj"),
    "a linewise selection takes whole lines wherever the cursor is"
  )
  assert_region(
    { lines = { "he", "se" }, start_lnum = 2, start_col = 1, end_lnum = 3, end_col = 2 },
    visual_region("2G0<C-v>jl"),
    "a blockwise selection takes the block of each line"
  )
end)

t:test("outside Visual mode only an explicit request reads the last selection", function()
  create_buffer({ "abc中x", "hello world" }, { current = true })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>gg0vl<Esc>"), "x", false)
  t.assert_nil(buf.retrieve_visual_region(), "a Normal mode caller has no selection")
  assert_region(
    { lines = { "ab" }, start_lnum = 1, start_col = 1, end_lnum = 1, end_col = 2 },
    buf.retrieve_visual_region(true),
    "a command run after Visual mode reads its marks"
  )
end)

---@param keys                          string Keys that end in Visual mode, where the text is read.
---@return string|nil text
---@return string mode after the read
---@return integer[] cursor after the read
local function selected_text(keys)
  local text = read_typed(keys, { "n", "x" }, buf.retrieve_selected_text, "")
  return text, vim.fn.mode(), vim.api.nvim_win_get_cursor(0)
end

---@return table<string, table>
local function register_state()
  return { v = vim.fn.getreginfo("v"), unnamed = vim.fn.getreginfo('"') }
end

t:test("selected text follows the Visual yank and leaves every register as it was", function()
  for _, case in ipairs({
    { keys = "gg0v3l", text = "abc中", cursor = { 1, 0 } },
    { keys = "2G0wv$", text = "world\n", cursor = { 2, 6 } },
    { keys = "3G$vk", text = "\nsecond line", cursor = { 2, 10 } },
    { keys = "2G6|Vj", text = "hello world\nsecond line\n", cursor = { 2, 0 } },
    { keys = "2G0<C-v>jl", text = "he\nse", cursor = { 2, 0 } },
    { keys = "2G0<C-v>j$", text = "hello world\nsecond line", cursor = { 2, 0 } },
  }) do
    vim.fn.setreg("v", { "kept", "block" }, "b")
    vim.fn.setreg('"', "last yank")
    local registers = register_state()

    local text, mode, cursor = selected_text(case.keys)

    t.assert_eq(case.text, text, case.keys .. " text")
    t.assert_eq("n", mode, case.keys .. " leaves Visual mode")
    t.assert_same(case.cursor, cursor, case.keys .. " cursor at the selection start")
    t.assert_same(registers, register_state(), case.keys .. " registers")
  end
end)

t:test("a Normal mode caller gets no selection, even with text in register v", function()
  vim.fn.setreg("v", "lua print('stale')")
  vim.fn.setreg('"', "last yank")
  local registers = register_state()

  local text, mode = selected_text("gg0w")

  t.assert_eq("", text, "Normal mode text")
  t.assert_eq("n", mode, "mode")
  t.assert_same(registers, register_state(), "registers")
end)

t:test("has_unsaved_changes counts only modified buffers that writing keeps", function()
  ---@param buftype                     string
  ---@param modified                    boolean
  ---@return integer
  local function buffer(buftype, modified)
    local bufnr = create_buffer()
    vim.api.nvim_set_option_value("buftype", buftype, { buf = bufnr })
    vim.api.nvim_set_option_value("modified", modified, { buf = bufnr })
    return bufnr
  end

  t.assert_true(buf.has_unsaved_changes(buffer("", true)), "modified file buffer")
  t.assert_true(buf.has_unsaved_changes(buffer("acwrite", true)), "modified acwrite buffer")
  t.assert_false(buf.has_unsaved_changes(buffer("", false)), "unmodified file buffer")
  t.assert_false(buf.has_unsaved_changes(buffer("nofile", true)), "modified scratch buffer")
  t.assert_false(buf.has_unsaved_changes(nil), "no buffer")
  t.assert_false(buf.has_unsaved_changes(999999), "invalid buffer")
end)

t:run()
