local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_runtime(t, {
  dot = {
    context = { flight = {}, plugin = {} },
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

---@param image                         table
---@return table
local function load_placement(image)
  t:patch_table(package.loaded, "era.m.image.image", {
    new = function()
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
    env = { placeholders = true },
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

t:run()
