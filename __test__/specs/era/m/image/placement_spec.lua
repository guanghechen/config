local harness = require("__test__.support.harness")
local support = require("__test__.support.image")

local t = harness.new()

support.with_inline(t)

local PLACEHOLDER = vim.fn.nr2char(0x10EEEE) ---@type string

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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  local bufnr = support.shown_buf(t)
  local other = support.shown_buf(t)
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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  local placed = {} ---@type integer[]
  t:patch_table(package.loaded["era.m.image.terminal"], "request", function(opts)
    if opts.a == "p" then
      placed[#placed + 1] = opts.i
    end
  end)
  local bufnr = support.shown_buf(t)
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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  local bufnr = support.shown_buf(t)
  support.shown_buf(t)
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
  t.drain()
  updates = 0
  vim.api.nvim_exec_autocmds("WinResized", {})
  t.drain()
  t.assert_eq(1, updates, "shown viewer")
end)

t:test("the loading spinner leaves only its own mark once the image is ready", function()
  local props = { ready = false }
  local image = support.fake_image(props)
  local Placement = support.load_placement(t, image)
  local bufnr = support.shown_buf(t)
  local other = vim.api.nvim_buf_set_extmark(bufnr, Placement.ns, 0, 0, {}) ---@type integer
  local placement = Placement.new(bufnr, image.src, {})
  t:defer(function()
    placement:close()
  end)

  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 1
  end, 5000, "spinner shown")
  t.assert_false(vim.api.nvim_get_option_value("modified", { buf = bufnr }), "viewer unmodified")
  props.ready = true
  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 0
  end, 5000, "spinner removed")
  t.assert_same({ 0, 0 }, vim.api.nvim_buf_get_extmark_by_id(bufnr, Placement.ns, other, {}), "other mark kept")
end)

t:test("closing a loading viewer removes its spinner", function()
  local image = support.fake_image({ ready = false })
  local Placement = support.load_placement(t, image)
  local bufnr = support.shown_buf(t)
  local placement = Placement.new(bufnr, image.src, {})
  t:defer(function()
    placement:close()
  end)

  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 1
  end, 5000, "spinner shown")
  placement:close()
  t.wait_until(function()
    return count_marks(bufnr, Placement.ns, "loading") == 0
  end, 5000, "spinner removed")
end)

t:test("an image is no wider than the text area of its windows", function()
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  t:patch_table(package.loaded["era.m.image.state"], "fit", function(_, cells)
    return cells
  end)
  local bufnr = support.shown_buf(t)
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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  t:patch_table(package.loaded["era.m.image.terminal"], "size", function()
    return { cell_width = 18, cell_height = 40, scale = 2.25 }
  end)
  local bufnr = support.shown_buf(t, { "a $m$ b" })

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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  t:patch_table(package.loaded["era.m.image.terminal"], "size", function()
    return { cell_width = 18, cell_height = 40, scale = 2.25 }
  end)
  -- Three rows at its own size, like `\displaystyle \epsilon = \frac{A}{2}`.
  t:patch_table(package.loaded["era.m.image.state"], "fit", function()
    return { width = 3, height = 3 }
  end)
  image.info = { size = { width = 88, height = 73 }, dpi = { width = 192, height = 192 } }
  local bufnr = support.shown_buf(t, { "a $m$ b" })
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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  -- Three rows, while text follows on the line: the icon keeps its place, the image goes below.
  t:patch_table(package.loaded["era.m.image.state"], "fit", function()
    return { width = 3, height = 3 }
  end)
  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]

  for _, case in ipairs({ { prefix = "abcd ", padding = 5 }, { prefix = string.rep("x", 200) .. " " } }) do
    local line = case.prefix .. "$m$ cd" ---@type string
    local bufnr = support.shown_buf(t, { line })
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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  -- Three rows: the first overlays the image's line, the others are virtual lines below it.
  t:patch_table(package.loaded["era.m.image.state"], "fit", function()
    return { width = 3, height = 3 }
  end)
  local prefix = "图 1：" ---@type string
  local line = prefix .. "![](a.png)" ---@type string
  local bufnr = support.shown_buf(t, { line })
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
  local image = support.fake_image({ ready = true })
  local Placement = support.load_placement(t, image)
  local bufnr = support.shown_buf(t)
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

t:run()
