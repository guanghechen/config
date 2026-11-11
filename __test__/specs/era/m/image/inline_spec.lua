local harness = require("__test__.support.harness")
local support = require("__test__.support.image")

local t = harness.new()

support.with_inline(t)

t:test("a document keeps one placement for an image that failed to convert", function()
  local image = support.fake_image({ ready = false, failed = true })
  support.load_placement(t, image)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local bufnr = support.shown_buf(t, { "![badge](https://example.com/badge.svg)" })
  ---@type era.m.image.match
  local match =
    { id = "1", src = image.src, pos = { 1, 0 }, range = { 1, 0, 1, 39 }, lang = "markdown", type = "image" }
  local inline = Inline.new(bufnr, {
    find_visible = function(_, cb)
      cb({ vim.deepcopy(match) })
    end,
    math_enabled = function()
      return false
    end,
  })
  t:defer(function()
    inline:dispose()
  end)

  for _ = 1, 3 do
    inline:update()
  end

  t.assert_eq(1, vim.tbl_count(inline.imgs), "placements")
end)

---A document of lines `<prefix>:<name>`, which follows the buffer text without a parser.
---@param prefix                        string
---@param kind                          era.m.image.Type
---@return era.m.image.inline.IDocument
local function lines_document(prefix, kind)
  return {
    find_visible = function(bufnr, cb)
      local matches = {} ---@type era.m.image.match[]
      for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        local name = line:match("^" .. prefix .. ":(%w+)$")
        if name then
          matches[#matches + 1] = {
            id = tostring(row),
            src = name,
            pos = { row, 0 },
            range = { row, 0, row, #line },
            lang = kind == "math" and "latex" or "markdown",
            type = kind,
          }
        end
      end
      cb(matches)
    end,
    math_enabled = function()
      return kind == "math"
    end,
  }
end

-- Images are lines `img:<name>`, formulas lines `math:<name>`.
local line_document = lines_document("img", "image")
local math_document = lines_document("math", "math")

---@param inline                        era.m.image.inline
---@return string[]
local function sources(inline)
  local srcs = {} ---@type string[]
  for _, placement in pairs(inline.imgs) do
    srcs[#srcs + 1] = placement.img.src
  end
  table.sort(srcs)
  return srcs
end

---@param lines                         string[]
---@return string, integer
local function edited_file(lines)
  local file = t:tempdir() .. "/doc.md" ---@type string
  vim.fn.writefile(lines, file)
  vim.cmd.edit(file)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return file, bufnr
end

t:test("a document reloaded from disk keeps following its edits", function()
  local images = {} ---@type table<string, table>
  support.load_placement(t, function(src)
    images[src] = images[src]
      or vim.tbl_extend("force", support.fake_image({ ready = false, failed = true }), { src = src })
    return images[src]
  end)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local file, bufnr = edited_file({ "img:a" })
  local inline = Inline.new(bufnr, line_document)
  t:defer(function()
    inline:dispose()
  end)

  ---@return string[]
  local function shown()
    local srcs = {} ---@type string[]
    for _, placement in pairs(inline.imgs) do
      srcs[#srcs + 1] = placement.img.src
    end
    table.sort(srcs)
    return srcs
  end

  inline:update()
  t.assert_same({ "a" }, shown(), "first read")

  vim.fn.writefile({ "img:a", "img:b" }, file)
  local later = os.time() + 10 ---@type integer
  vim.uv.fs_utime(file, later, later)
  vim.cmd("checktime")
  t.wait_until(function()
    return vim.deep_equal({ "a", "b" }, shown())
  end, 5000, "reloaded text")

  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "img:c" })
  t.wait_until(function()
    return vim.deep_equal({ "a", "b", "c" }, shown())
  end, 5000, "edit after the reload")
end)

t:test("a document reloaded while another tab shows draws once its tab does, with one placement an image", function()
  support.load_placement(t, function(src)
    return vim.tbl_extend("force", support.fake_image({ ready = true }), { src = src })
  end)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local file, bufnr = edited_file({ "img:a" })
  local inline = Inline.new(bufnr, line_document)
  t:defer(function()
    inline:dispose()
  end)
  inline:update()
  local document_tab = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd("tabnew")
  t:defer(function()
    pcall(vim.cmd, "tabonly!")
  end)

  vim.fn.writefile({ "img:a", "text" }, file)
  local later = os.time() + 10 ---@type integer
  vim.uv.fs_utime(file, later, later)
  vim.cmd("checktime " .. bufnr)
  t.wait_until(function()
    return vim.api.nvim_buf_line_count(bufnr) == 2
  end, 5000, "reloaded while another tab shows")
  vim.wait(300)

  vim.api.nvim_set_current_tabpage(document_tab)
  t.wait_until(function()
    for _, placement in pairs(inline.imgs) do
      if placement.img.src == "a" and #placement.eids > 0 then
        return true
      end
    end
    return false
  end, 5000, "drawn once its tab shows")

  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "more" })
  vim.wait(300)
  inline:update()
  t.assert_same({ "a" }, sources(inline), "one placement after more updates")
end)

t:test("turning dressing_image off removes every image until it is on again", function()
  local shown = true ---@type boolean
  t:patch_table(dot.context.flight, "dressing_image", {
    snapshot = function()
      return shown
    end,
  })
  local images = {} ---@type table<string, table>
  support.load_placement(t, function(src)
    images[src] = images[src]
      or vim.tbl_extend("force", support.fake_image({ ready = false, failed = true }), { src = src })
    return images[src]
  end)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local _, bufnr = edited_file({ "img:a", "img:b" })
  local inline = Inline.new(bufnr, line_document)
  t:defer(function()
    inline:dispose()
  end)
  inline:update()
  t.assert_eq(2, vim.tbl_count(inline.imgs), "images shown")

  shown = false
  inline:sync()
  t.assert_eq(0, vim.tbl_count(inline.imgs), "images removed")
  inline:update()
  t.assert_eq(0, vim.tbl_count(inline.imgs), "nothing drawn while off")

  shown = true
  inline:sync()
  t.assert_eq(2, vim.tbl_count(inline.imgs), "images back")
end)

t:test("an image shows its source only while the cursor is on its line", function()
  support.load_placement(t, function(src)
    return vim.tbl_extend("force", support.fake_image({ ready = true }), { src = src })
  end)
  t:patch_table(package.loaded["era.m.image.state"].data.doc, "conceal", function()
    return true
  end)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local _, bufnr = edited_file({ "text", "img:a", "text" })
  local inline = Inline.new(bufnr, line_document)
  t:defer(function()
    inline:dispose()
  end)
  inline:update()
  local placement = assert(vim.tbl_values(inline.imgs)[1]) ---@type era.m.image.Placement
  t.wait_until(function()
    return #placement.eids > 0
  end, 5000, "image drawn")

  for row, hidden in ipairs({ false, true, false }) do
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    inline:conceal()
    t.assert_eq(hidden, placement.hidden == true, "cursor on line " .. row)
  end
end)

---Formulas concealed like the real ones, in a document being edited in `concealcursor`.
---@param concealcursor                 string
---@return era.m.image.inline, integer
local function typed_formulas(concealcursor)
  support.load_placement(t, function(src)
    return vim.tbl_extend("force", support.fake_image({ ready = false }), { src = src })
  end)
  t:patch_table(package.loaded["era.m.image.state"].data.doc, "conceal", function(_, kind)
    return kind == "math"
  end)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local _, bufnr = edited_file({ "math:a", "math:b" })
  vim.api.nvim_set_option_value("concealcursor", concealcursor, { win = 0, scope = "local" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local inline = Inline.new(bufnr, math_document)
  t:defer(function()
    inline:dispose()
  end)
  return inline, bufnr
end

t:test("a formula on the line being typed waits until typing ends", function()
  local inline, bufnr = typed_formulas("nvc")
  local mode = "i" ---@type string
  t:patch_table(vim.fn, "mode", function()
    return mode
  end)

  inline:update()
  t.assert_same({ "b" }, sources(inline), "the formula on the typed line waits")

  mode = "n"
  vim.api.nvim_exec_autocmds("ModeChanged", { buffer = bufnr })
  t.wait_until(function()
    return vim.deep_equal({ "a", "b" }, sources(inline))
  end, 5000, "drawn once typing ended")
end)

t:test("keys typed in a very long line rescan the images once typing ends", function()
  support.load_placement(t, support.fake_image({ ready = false }))
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local _, bufnr = edited_file({ "text", string.rep("x", 70 * 1024), "text" })
  local scans = 0 ---@type integer
  local inline = Inline.new(bufnr, {
    find_visible = function(_, cb)
      scans = scans + 1
      cb({})
    end,
    math_enabled = function()
      return false
    end,
  })
  t:defer(function()
    inline:dispose()
  end)
  t.wait_until(function()
    return scans == 1
  end, 5000, "first scan")
  local mode = "i" ---@type string
  t:patch_table(vim.fn, "mode", function()
    return mode
  end)

  for _ = 1, 3 do
    vim.api.nvim_buf_set_text(bufnr, 1, 0, 1, 0, { "y" })
  end
  vim.wait(300)
  t.assert_eq(1, scans, "keys typed in the long line wait")
  vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { "y" })
  t.wait_until(function()
    return scans == 2
  end, 5000, "a key typed in a short line rescans")
  vim.api.nvim_buf_set_text(bufnr, 1, 0, 1, 0, { "y" })
  mode = "n"
  vim.api.nvim_exec_autocmds("ModeChanged", { buffer = bufnr })
  t.wait_until(function()
    return scans == 3
  end, 5000, "rescanned once typing ended")
  vim.api.nvim_buf_set_text(bufnr, 1, 0, 1, 0, { "y" })
  t.wait_until(function()
    return scans == 4
  end, 5000, "a change outside Insert mode rescans at once")
end)

t:test("a formula that concealcursor shows while typing is drawn at once", function()
  local inline = typed_formulas("nvic")
  t:patch_table(vim.fn, "mode", function()
    return "i"
  end)

  inline:update()

  t.assert_same({ "a", "b" }, sources(inline), "both formulas")
end)

t:test("a formula on the cursor line shows again once concealcursor lets it, set after the mode changed", function()
  support.load_placement(t, function(src)
    return vim.tbl_extend("force", support.fake_image({ ready = true }), { src = src })
  end)
  t:patch_table(package.loaded["era.m.image.state"].data.doc, "conceal", function(_, kind)
    return kind == "math"
  end)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local _, bufnr = edited_file({ "math:a" })
  vim.api.nvim_set_option_value("concealcursor", "nvc", { win = 0, scope = "local" })
  local inline = Inline.new(bufnr, math_document)
  t:defer(function()
    inline:dispose()
  end)
  inline:update()
  local placement = assert(vim.tbl_values(inline.imgs)[1]) ---@type era.m.image.Placement
  t.wait_until(function()
    return #placement.eids > 0
  end, 5000, "image drawn")
  local mode = "i" ---@type string
  t:patch_table(vim.fn, "mode", function()
    return mode
  end)

  -- As with render-markdown: Insert mode changes concealcursor, which comes back only once Normal mode began.
  vim.api.nvim_set_option_value("concealcursor", "", { win = 0, scope = "local" })
  inline:conceal()
  t.assert_true(placement.hidden == true, "source while typing")
  mode = "n"
  inline:conceal()
  vim.api.nvim_set_option_value("concealcursor", "nvc", { win = 0, scope = "local" })

  t.assert_false(placement.hidden == true, "drawn again in Normal mode")
end)

t:test("unloading a document disposes its renderer", function()
  support.load_placement(t, support.fake_image({ ready = false, failed = true }))
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local file, bufnr = edited_file({ "img:a" })

  for _, unload in ipairs({ "edit!", "bdelete" }) do
    vim.cmd.edit(file)
    local inline = Inline.new(bufnr, line_document)
    inline:update()
    t.assert_eq(1, vim.tbl_count(inline.imgs), unload .. ": placements")

    vim.cmd(unload)

    t.assert_true(inline.disposed == true, unload .. ": disposed")
    t.assert_eq(0, vim.tbl_count(inline.imgs), unload .. ": placements closed")
    t.assert_false(pcall(vim.api.nvim_get_autocmds, { group = "era.m.image.inline." .. bufnr }), unload .. ": autocmds")
  end
end)

t:run()
