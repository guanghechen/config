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

---@return integer
local function create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    buf.on_buf_close(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
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
  t:patch_table(stl.env, "IS_WIN", true)
  t:patch_table(yoz.path, "normalize", function(filepath)
    return filepath:gsub("\\", "/")
  end)

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
  local literal_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local nested_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(literal_bufnr, literal)
  vim.api.nvim_buf_set_name(nested_bufnr, nested)

  t.assert_eq(literal_bufnr, buf.locate_bufnr(literal), "literal backslash buffer")
  t.assert_eq(nested_bufnr, buf.locate_bufnr(nested), "nested path buffer")

  vim.api.nvim_buf_delete(literal_bufnr, { force = true })
  vim.api.nvim_buf_delete(nested_bufnr, { force = true })
end)

t:test("POSIX lookup keeps literal environment variables distinct from expanded paths", function()
  local literal = vim.fn.tempname() .. "/$HOME/file.lua"
  local expanded = vim.fs.normalize(literal)
  t.assert_true(literal ~= expanded, "fixture must exercise environment expansion")

  local literal_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local expanded_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(literal_bufnr, literal)
  vim.api.nvim_buf_set_name(expanded_bufnr, expanded)

  t.assert_eq(literal_bufnr, buf.locate_bufnr(literal), "literal environment variable buffer")
  t.assert_eq(expanded_bufnr, buf.locate_bufnr(expanded), "expanded path buffer")

  vim.api.nvim_buf_delete(literal_bufnr, { force = true })
  vim.api.nvim_buf_delete(expanded_bufnr, { force = true })
end)

t:test("refreshing a renamed buffer replaces the cached filepath", function()
  local prefix = vim.fn.tempname() ---@type string
  local bufnr = create_cached_buffer(prefix .. "-old.lua")
  local old_filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  vim.api.nvim_buf_set_name(bufnr, prefix .. "-new.lua")
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
  t:patch_table(stl.env, "IS_WIN", true)
  t:patch_table(yoz.path, "normalize", function(filepath)
    return filepath:gsub("\\", "/")
  end)

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

---@param keys                          string Keys that end in Visual mode, where the region is read.
---@return stl.nvim.buf.IVisualRegion|nil
local function visual_region(keys)
  local bufnr = create_buffer()
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "abc中x", "hello world", "second line" })
  local region ---@type stl.nvim.buf.IVisualRegion|nil
  vim.keymap.set("x", "<F2>", function()
    region = buf.retrieve_visual_region()
  end, { buffer = bufnr })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>" .. keys .. "<F2><Esc>"), "x", false)
  return region
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
  local bufnr = create_buffer()
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "abc中x", "hello world" })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>gg0vl<Esc>"), "x", false)
  t.assert_nil(buf.retrieve_visual_region(), "a Normal mode caller has no selection")
  assert_region(
    { lines = { "ab" }, start_lnum = 1, start_col = 1, end_lnum = 1, end_col = 2 },
    buf.retrieve_visual_region(true),
    "a command run after Visual mode reads its marks"
  )
end)

t:run()
