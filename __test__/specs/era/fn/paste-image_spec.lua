local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new()
local native = require("yoz")
local filetype = require("stl.filetype")

bootstrap.with_global(t, "yoz", native)
bootstrap.with_global(t, "stl", {
  filetype = filetype,
  env = {
    PATH_SEP = "/",
    mkdirs = function(path)
      vim.fn.mkdir(vim.fs.dirname(path), "p")
    end,
  },
})
bootstrap.with_global(t, "dot", { path = {}, context = { module = {} } })
bootstrap.with_global(t, "era", { m = { clipboard = {}, input = {} } })
local paste = dofile("lua/era/fn/paste-image.lua")

---@param ft                            string
---@return table
local function prepare(ft)
  local root = t:tempdir()
  root = assert(vim.uv.fs_realpath(root))
  local bufnr = vim.api.nvim_create_buf(false, false)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_name(bufnr, root .. "/note.md")
  vim.api.nvim_set_option_value("filetype", ft, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "source" })
  vim.api.nvim_set_current_buf(bufnr)
  local state = { root = root, bufnr = bufnr, has_image = true, save_ok = true, saves = {} }
  t:patch_table(dot, "path", {
    cwd = function()
      return root
    end,
    workspace = function()
      return root
    end,
    dirname = vim.fs.dirname,
    join = vim.fs.joinpath,
    relative = function(from, to, separator)
      return native.path.relative(from, to, false, separator or "/")
    end,
    resolve = function(from, to)
      return native.path.resolve(from, to, false, "/")
    end,
  })
  t:patch_table(dot.context.module, "paste_image_filepath", {
    snapshot = function()
      return "assets/image.png"
    end,
    next = function(_, value)
      state.saved_path = value
    end,
  })
  t:patch_table(era.m, "clipboard", {
    has_image = function()
      return state.has_image
    end,
    paste_image_from_clipboard = function(path)
      state.saves[#state.saves + 1] = path
      return state.save_ok
    end,
  })
  t:patch_table(era.m.input, "open", function(_, callback)
    state.confirm = callback
    return vim.api.nvim_get_current_win()
  end)
  return state
end

t:test("Markdown and notepad image links encode spaces while preserving Unicode", function()
  for _, ft in ipairs({ "markdown", filetype.NOTEPAD }) do
    local state = prepare(ft)
    paste()
    state.confirm("assets/示例 image.png")
    t.wait_until(function()
      return vim.api.nvim_buf_line_count(state.bufnr) == 2
    end, 1000, "deferred image link")
    t.assert_eq("![示例 image](./assets/示例%20image.png)", vim.api.nvim_buf_get_lines(state.bufnr, 1, 2, false)[1])
    t.assert_eq(state.root .. "/assets/示例 image.png", state.saves[1], "filesystem path stays unescaped")
    t.assert_eq("assets/示例 image.png", state.saved_path, "saved path state")
  end
end)

t:test("confirming after a focus change inserts only into the originating buffer", function()
  local state = prepare("markdown")
  paste()
  local other = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(other, { force = true })
  end)
  vim.api.nvim_buf_set_lines(other, 0, -1, false, { "other" })
  vim.api.nvim_set_current_buf(other)
  state.confirm("assets/image.png")
  t.wait_until(function()
    return vim.api.nvim_buf_line_count(state.bufnr) == 2
  end, 1000, "originating buffer receives image link")
  t.assert_eq("![image](./assets/image.png)", vim.api.nvim_buf_get_lines(state.bufnr, 1, 2, false)[1])
  t.assert_eq(1, vim.api.nvim_buf_line_count(other))
  t.assert_eq("other", vim.api.nvim_buf_get_lines(other, 0, 1, false)[1])
  t.assert_eq(other, vim.api.nvim_get_current_buf(), "focus is preserved")
end)

t:test("missing images, cancelled input and save failures do not insert references", function()
  local state = prepare("markdown")
  state.has_image = false
  paste()
  t.assert_nil(state.confirm, "no prompt without an image")
  state.has_image = true
  paste()
  state.confirm(nil)
  state.confirm("")
  t.assert_eq(0, #state.saves, "cancelled input does not save")
  state.save_ok = false
  state.confirm("assets/failure.png")
  t.assert_eq(1, #state.saves)
  t.assert_nil(state.saved_path, "failed save does not update state")
  t.assert_eq(1, vim.api.nvim_buf_line_count(state.bufnr))
end)

t:test("a wiped originating buffer never redirects insertion to the current buffer", function()
  local state = prepare("markdown")
  paste()
  vim.api.nvim_buf_delete(state.bufnr, { force = true })
  local current = vim.api.nvim_get_current_buf()
  local before = vim.api.nvim_buf_get_changedtick(current)
  state.confirm("assets/image.png")
  t.assert_eq(before, vim.api.nvim_buf_get_changedtick(current))
  t.assert_eq(1, #state.saves, "the requested image save still succeeds")
end)

t:run()
