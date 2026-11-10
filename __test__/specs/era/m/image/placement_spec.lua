local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_runtime(t, {
  dot = {
    context = {
      flight = {
        dressing_image = {
          snapshot = function()
            return true
          end,
        },
      },
      plugin = {},
    },
    var = { N_IMAGE_CONCEAL = "image_placement_conceal" },
  },
  stl = {
    fn = {
      observe = function()
        return { unsubscribe = function() end }
      end,
    },
    timer = require("stl.timer"),
  },
})

local PLACEHOLDER = vim.fn.nr2char(0x10EEEE) ---@type string

---@param props                         { ready: boolean, failed?: boolean }
---@return table
local function fake_image(props)
  local image = { id = 7, src = "/images/a.png", file = "/images/a.png", sent = true, placements = {} }
  function image:ready()
    return props.ready
  end
  function image:failed()
    return props.failed == true
  end
  function image:latest()
    return self
  end
  function image:place(placement)
    self.placements[placement.id] = placement
  end
  function image:del(id)
    self.placements[id] = nil
  end
  image.convert = {
    current = function()
      return { name = "convert" }
    end,
  }
  return image
end

---@param image                         table|fun(src: string): table
---@return table
local function load_placement(image)
  t:patch_table(package.loaded, "era.m.image.image", {
    new = type(image) == "function" and image or function()
      return image
    end,
  })
  t:patch_table(package.loaded, "era.m.image.state", {
    data = {
      wo = {},
      icons = { image = "I" },
      doc = {
        conceal = function()
          return false
        end,
      },
    },
    fit = function()
      return { width = 3, height = 2 }
    end,
  })
  t:patch_table(package.loaded, "era.m.image.terminal", { request = function() end })
  local Placement = assert(loadfile("lua/era/m/image/placement.lua"))()
  t:patch_table(package.loaded, "era.m.image.placement", Placement)
  return Placement
end

---@param lines                         ?string[]
---@return integer
local function shown_buf(lines)
  -- A file buffer, like the viewer's, tracks `modified`.
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or {})
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  vim.api.nvim_win_set_buf(0, bufnr)
  return bufnr
end

---@param bufnr                         integer
---@param ns                            integer
---@param text                          string
---@return integer
local function count_marks(bufnr, ns, text)
  local count = 0 ---@type integer
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })) do
    local chunks = vim.deepcopy(mark[4].virt_text or {}) ---@type table[]
    for _, line in ipairs(mark[4].virt_lines or {}) do
      vim.list_extend(chunks, line)
    end
    for _, chunk in ipairs(chunks) do
      if chunk[1]:find(text, 1, true) then
        count = count + 1
        break
      end
    end
  end
  return count
end

t:test("a viewer shows its image again after its buffer returns to a window", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  local bufnr = shown_buf()
  local other = shown_buf()
  vim.api.nvim_win_set_buf(0, bufnr)
  local placement = Placement.new(bufnr, image.src, { conceal = true })
  t:defer(function()
    placement:close()
  end)

  Placement.update(placement)
  t.assert_true(count_marks(bufnr, Placement.ns, PLACEHOLDER) > 0, "first render")

  vim.api.nvim_win_set_buf(0, other)
  Placement.update(placement)
  vim.api.nvim_win_set_buf(0, bufnr)
  Placement.update(placement)

  t.assert_nil(placement.hidden, "conceal state")
  t.assert_true(count_marks(bufnr, Placement.ns, PLACEHOLDER) > 0, "render after returning")
end)

t:test("a placement draws again when its image goes under another id", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  local placed = {} ---@type integer[]
  t:patch_table(package.loaded["era.m.image.terminal"], "request", function(opts)
    if opts.a == "p" then
      placed[#placed + 1] = opts.i
    end
  end)
  local bufnr = shown_buf()
  local placement = Placement.new(bufnr, image.src, { conceal = true })
  t:defer(function()
    placement:close()
  end)
  Placement.update(placement)

  image.id = 8
  Placement.update(placement)

  t.assert_same({ 7, 8 }, placed, "placed under each id")
  t.assert_eq(8, vim.api.nvim_get_hl(0, { name = "m_img_" .. placement.id }).fg, "placeholders name the new id")
end)

t:test("window events leave a viewer that no window shows alone", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  local bufnr = shown_buf()
  shown_buf()
  local placement = Placement.new(bufnr, image.src, { conceal = true, auto_resize = true })
  t:defer(function()
    placement:close()
  end)
  vim.wait(50)
  local updates = 0 ---@type integer
  placement.update = function()
    updates = updates + 1
  end

  vim.api.nvim_exec_autocmds("WinEnter", {})
  vim.api.nvim_exec_autocmds("WinResized", {})
  vim.wait(50)
  t.assert_eq(0, updates, "hidden viewer")

  vim.api.nvim_win_set_buf(0, bufnr)
  vim.wait(50)
  updates = 0
  vim.api.nvim_exec_autocmds("WinResized", {})
  vim.wait(50)
  t.assert_eq(1, updates, "shown viewer")
end)

t:test("the loading spinner leaves only its own mark once the image is ready", function()
  local props = { ready = false }
  local image = fake_image(props)
  local Placement = load_placement(image)
  local bufnr = shown_buf()
  local other = vim.api.nvim_buf_set_extmark(bufnr, Placement.ns, 0, 0, {}) ---@type integer
  local placement = Placement.new(bufnr, image.src, {})
  t:defer(function()
    placement:close()
  end)

  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 1
  end, 1000, "spinner shown")
  t.assert_false(vim.api.nvim_get_option_value("modified", { buf = bufnr }), "viewer unmodified")
  props.ready = true
  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 0
  end, 1000, "spinner removed")
  t.assert_same({ 0, 0 }, vim.api.nvim_buf_get_extmark_by_id(bufnr, Placement.ns, other, {}), "other mark kept")
end)

t:test("closing a loading viewer removes its spinner", function()
  local image = fake_image({ ready = false })
  local Placement = load_placement(image)
  local bufnr = shown_buf()
  local placement = Placement.new(bufnr, image.src, {})

  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 1
  end, 1000, "spinner shown")
  placement:close()
  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 0
  end, 1000, "spinner removed")
end)

t:test("a document keeps one placement for an image that failed to convert", function()
  local image = fake_image({ ready = false, failed = true })
  load_placement(image)
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local bufnr = shown_buf({ "![badge](https://example.com/badge.svg)" })
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
  load_placement(function(src)
    images[src] = images[src] or vim.tbl_extend("force", fake_image({ ready = false, failed = true }), { src = src })
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
  end, 2000, "reloaded text")

  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "img:c" })
  t.wait_until(function()
    return vim.deep_equal({ "a", "b", "c" }, shown())
  end, 2000, "edit after the reload")
end)

t:test("a document reloaded while another tab shows draws once its tab does, with one placement an image", function()
  load_placement(function(src)
    return vim.tbl_extend("force", fake_image({ ready = true }), { src = src })
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
  end, 2000, "reloaded while another tab shows")
  vim.wait(300)

  vim.api.nvim_set_current_tabpage(document_tab)
  t.wait_until(function()
    for _, placement in pairs(inline.imgs) do
      if placement.img.src == "a" and #placement.eids > 0 then
        return true
      end
    end
    return false
  end, 2000, "drawn once its tab shows")

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
  load_placement(function(src)
    images[src] = images[src] or vim.tbl_extend("force", fake_image({ ready = false, failed = true }), { src = src })
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
  load_placement(function(src)
    return vim.tbl_extend("force", fake_image({ ready = true }), { src = src })
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
  end, 1000, "image drawn")

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
  load_placement(function(src)
    return vim.tbl_extend("force", fake_image({ ready = false }), { src = src })
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
  end, 2000, "drawn once typing ended")
end)

t:test("keys typed in a very long line rescan the images once typing ends", function()
  load_placement(fake_image({ ready = false }))
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
  end, 1000, "first scan")
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
  end, 1000, "a key typed in a short line rescans")
  vim.api.nvim_buf_set_text(bufnr, 1, 0, 1, 0, { "y" })
  mode = "n"
  vim.api.nvim_exec_autocmds("ModeChanged", { buffer = bufnr })
  t.wait_until(function()
    return scans == 3
  end, 1000, "rescanned once typing ended")
  vim.api.nvim_buf_set_text(bufnr, 1, 0, 1, 0, { "y" })
  t.wait_until(function()
    return scans == 4
  end, 1000, "a change outside Insert mode rescans at once")
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
  load_placement(function(src)
    return vim.tbl_extend("force", fake_image({ ready = true }), { src = src })
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
  end, 1000, "image drawn")
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

t:test("an image is no wider than the text area of its windows", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  t:patch_table(package.loaded["era.m.image.state"], "fit", function(_, cells)
    return cells
  end)
  local bufnr = shown_buf()
  vim.api.nvim_set_option_value("number", true, { win = 0, scope = "local" })
  local placement = Placement.new(bufnr, image.src, { inline = true, max_width = 1000 })
  t:defer(function()
    placement:close()
  end)

  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  t.assert_true(info.textoff > 0, "line numbers take columns")
  t.assert_eq(info.width - info.textoff, Placement.state(placement).loc.width, "image width")
end)

t:test("an inline formula takes one row and the columns its pixels need at that height", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  t:patch_table(package.loaded["era.m.image.terminal"], "size", function()
    return { cell_width = 18, cell_height = 40, scale = 2.25 }
  end)
  local bufnr = shown_buf({ "a $m$ b" })

  -- 42px tall like every inline formula, they are all scaled by 40/42 to fill the row.
  for _, case in ipairs({ { pixels = 269, columns = 15 }, { pixels = 60, columns = 4 }, { pixels = 23, columns = 2 } }) do
    image.info = { size = { width = case.pixels, height = 42 }, dpi = { width = 192, height = 192 } }
    local placement = Placement.new(bufnr, image.src, { inline = true, pos = { 1, 2 }, range = { 1, 2, 1, 5 } })
    t:defer(function()
      placement:close()
    end)

    local loc = Placement.state(placement).loc
    t.assert_same({ case.columns, 1 }, { loc.width, loc.height }, case.pixels .. "px wide")
  end
end)

t:test("a formula in a line of text takes one row however tall, where an image goes below", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  t:patch_table(package.loaded["era.m.image.terminal"], "size", function()
    return { cell_width = 18, cell_height = 40, scale = 2.25 }
  end)
  -- Three rows at its own size, like `\displaystyle \epsilon = \frac{A}{2}`.
  t:patch_table(package.loaded["era.m.image.state"], "fit", function()
    return { width = 3, height = 3 }
  end)
  image.info = { size = { width = 88, height = 73 }, dpi = { width = 192, height = 192 } }
  local bufnr = shown_buf({ "a $m$ b" })
  local at = { inline = true, pos = { 1, 2 }, range = { 1, 2, 1, 5 } }
  local formula = Placement.new(bufnr, image.src, vim.tbl_extend("force", at, { type = "math" }))
  local picture = Placement.new(bufnr, image.src, vim.tbl_extend("force", at, { type = "image" }))
  t:defer(function()
    formula:close()
    picture:close()
  end)

  local loc = Placement.state(formula).loc
  t.assert_same({ 3, 1 }, { loc.width, loc.height }, "formula")
  t.assert_eq(3, Placement.state(picture).loc.height, "image")
end)

t:test("an image too tall for its line sits below it, under its place within the window", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  -- Three rows, while text follows on the line: the icon keeps its place, the image goes below.
  t:patch_table(package.loaded["era.m.image.state"], "fit", function()
    return { width = 3, height = 3 }
  end)
  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]

  for _, case in ipairs({ { prefix = "abcd ", padding = 5 }, { prefix = string.rep("x", 200) .. " " } }) do
    local line = case.prefix .. "$m$ cd" ---@type string
    local bufnr = shown_buf({ line })
    local room = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    local placement = Placement.new(bufnr, image.src, {
      inline = true,
      conceal = true,
      pos = { 1, #case.prefix },
      range = { 1, #case.prefix, 1, #case.prefix + 3 },
    })
    t:defer(function()
      placement:close()
    end)

    Placement.update(placement)

    local paddings = {} ---@type integer[]
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, Placement.ns, 0, -1, { details = true })) do
      for _, virt_line in ipairs(mark[4].virt_lines or {}) do
        -- The image right away, or blank columns before it.
        local first = virt_line[1][1] ---@type string
        paddings[#paddings + 1] = first:find(PLACEHOLDER, 1, true) and 0 or vim.fn.strdisplaywidth(first)
      end
    end
    -- A prefix wider than the window leaves the image at its right edge.
    local padding = case.padding or (room.width - room.textoff - 3)
    t.assert_same({ padding, padding, padding }, paddings, "padding after " .. #case.prefix .. " columns")
  end
  t.assert_true(info.width - info.textoff < 200, "the long prefix is wider than the window")
end)

t:test("an image after wide characters starts at their display width", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  -- Three rows: the first overlays the image's line, the others are virtual lines below it.
  t:patch_table(package.loaded["era.m.image.state"], "fit", function()
    return { width = 3, height = 3 }
  end)
  local prefix = "图 1：" ---@type string
  local line = prefix .. "![](a.png)" ---@type string
  local bufnr = shown_buf({ line })
  local placement = Placement.new(bufnr, image.src, {
    inline = true,
    conceal = true,
    pos = { 1, #prefix },
    range = { 1, #prefix, 1, #line },
  })
  t:defer(function()
    placement:close()
  end)

  Placement.update(placement)

  local columns = {} ---@type integer[]
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, Placement.ns, 0, -1, { details = true })) do
    columns[#columns + 1] = mark[4].virt_text_win_col
    for _, virt_line in ipairs(mark[4].virt_lines or {}) do
      columns[#columns + 1] = vim.api.nvim_strwidth(virt_line[1][1])
    end
  end
  t.assert_same({ 6, 6, 6 }, columns, "image columns")
end)

t:test("a closed placement passes its id and highlight group on", function()
  local image = fake_image({ ready = true })
  local Placement = load_placement(image)
  local bufnr = shown_buf()
  local first = Placement.new(bufnr, image.src, { conceal = true })
  Placement.update(first)
  first:close()
  local groups = vim.tbl_count(vim.api.nvim_get_hl(0, {})) ---@type integer

  for _ = 1, 20 do
    local placement = Placement.new(bufnr, image.src, { conceal = true })
    Placement.update(placement)
    t.assert_eq(first.id, placement.id, "placement id")
    placement:close()
  end

  t.assert_eq(groups, vim.tbl_count(vim.api.nvim_get_hl(0, {})), "highlight groups")
end)

t:test("unloading a document disposes its renderer", function()
  load_placement(fake_image({ ready = false, failed = true }))
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
