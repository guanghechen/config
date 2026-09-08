--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/image/ownership_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.image.ownership")

bootstrap.with_runtime(t, {
  dot = {
    context = { flight = {} },
    path = {
      join = function(left, right)
        return left .. "/" .. right
      end,
    },
    var = { N_IMAGE_ATTACHED = "image_ownership_attached" },
  },
  stl = {
    env = {
      IS_GHOSTTY = false,
      IS_KITTY = false,
      IS_TMUX = false,
      IS_WEZTERM = false,
    },
    table = require("stl.table"),
    timer = require("stl.timer"),
  },
  yoz = {},
})

t:test("placement owns identity before registering with an image", function()
  local registered = {} ---@type integer[]
  local image = {
    place = function(_, placement)
      registered[#registered + 1] = placement.id
    end,
    ready = function()
      return false
    end,
    failed = function()
      return false
    end,
    del = function() end,
  }
  t:patch_table(package.loaded, "era.m.image.image", {
    new = function()
      return image
    end,
  })

  local Placement = assert(loadfile("lua/era/m/image/placement.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  local first = Placement.new(bufnr, "first.png", { inline = true, pos = { 1, 0 } })
  local second = Placement.new(bufnr, "second.png", { inline = true, pos = { 1, 0 } })

  t.assert_eq(11, first.id, "first placement id")
  t.assert_eq(12, second.id, "second placement id")
  t.assert_true(vim.deep_equal({ 11, 12 }, registered), "registered ids")
  first:close()
  second:close()
end)

t:test("image registration requires placement-owned identity", function()
  local Image = assert(loadfile("lua/era/m/image/image.lua"))()
  local image = setmetatable({ placements = {} }, Image)

  local ok, err = pcall(function()
    image:place({})
  end)

  t.assert_false(ok, "missing placement identity")
  t.assert_true(tostring(err):find("placement.id", 1, true) ~= nil, "identity error")
end)

t:test("inline validates the injected document contract synchronously", function()
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  local ok_document, document_err = pcall(Inline.new, bufnr, nil)
  local ok_find, find_err = pcall(Inline.new, bufnr, {})
  local ok_math, math_err = pcall(Inline.new, bufnr, { find_visible = function() end })

  t.assert_false(ok_document, "missing document")
  t.assert_true(tostring(document_err):find("document should be a table", 1, true) ~= nil, "document error")
  t.assert_false(ok_find, "missing find_visible")
  t.assert_true(tostring(find_err):find("document.find_visible", 1, true) ~= nil, "find_visible error")
  t.assert_false(ok_math, "missing math_enabled")
  t.assert_true(tostring(math_err):find("document.math_enabled", 1, true) ~= nil, "math_enabled error")
end)

t:test("image sizing preserves the state facade", function()
  t:patch_table(package.loaded, "era.m.image.terminal", {
    size = function()
      return {
        width = 1000,
        height = 1000,
        columns = 100,
        rows = 50,
        cell_width = 10,
        cell_height = 20,
        scale = 1,
      }
    end,
  })

  local state = assert(loadfile("lua/era/m/image/state.lua"))()
  local size = state.fit("unused.png", { width = 20, height = 20 }, {
    info = {
      size = { width = 100, height = 100 },
      dpi = { width = 96, height = 96 },
    },
  })

  t.assert_true(vim.deep_equal({ width = 10, height = 5 }, size), "cell size")
end)

t:test("terminal output reads the environment owner without loading state", function()
  local output = nil ---@type string|nil
  local state_reads = 0 ---@type integer
  t:patch_table(package.loaded, "era.m.image.env", {
    transform = function(data)
      return "wrapped:" .. data
    end,
  })
  t:patch_table(
    package.loaded,
    "era.m.image.state",
    setmetatable({}, {
      __index = function()
        state_reads = state_reads + 1
      end,
    })
  )
  t:patch_table(vim.api, "nvim_ui_send", function(data)
    output = data
  end)

  local terminal = assert(loadfile("lua/era/m/image/terminal.lua"))()
  terminal.write("payload")

  t.assert_eq("wrapped:payload", output, "terminal output")
  t.assert_eq(0, state_reads, "state reads")
end)

t:test("document injects its query contract into inline rendering", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local provider = nil ---@type era.m.image.inline.IDocument|nil
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  t:patch_table(dot.context.flight, "dressing_image", {
    snapshot = function()
      return true
    end,
  })
  t:patch_table(package.loaded, "era.m.image.state", {
    data = { doc = { inline = true, float = true } },
    env = { placeholders = true },
  })
  t:patch_table(package.loaded, "era.m.image.inline", {
    new = function(_, document)
      provider = document
    end,
  })

  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  document.attach(bufnr)

  t.assert_eq(document, provider, "document provider")
end)

t:run()
