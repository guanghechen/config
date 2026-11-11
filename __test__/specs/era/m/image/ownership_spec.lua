local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_runtime(t, {
  dot = {
    context = { flight = {} },
    path = {
      join = function(left, right)
        return left .. "/" .. right
      end,
    },
  },
  stl = {
    env = {
      IS_GHOSTTY = false,
      IS_KITTY = false,
      IS_TMUX = false,
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
  local bufnr = t:buffer()

  local first = Placement.new(bufnr, "first.png", { inline = true, pos = { 1, 0 } })
  t:defer(function()
    first:close()
  end)
  local second = Placement.new(bufnr, "second.png", { inline = true, pos = { 1, 0 } })
  t:defer(function()
    second:close()
  end)

  t.assert_eq(11, first.id, "first placement id")
  t.assert_eq(12, second.id, "second placement id")
  t.assert_same({ 11, 12 }, registered, "registered ids")
end)

t:test("image registration requires placement-owned identity", function()
  local Image = assert(loadfile("lua/era/m/image/image.lua"))()
  local image = setmetatable({ placements = {} }, Image)

  t.assert_error(function()
    image:place({})
  end, "placement.id", "missing placement identity")
end)

t:test("inline validates the injected document contract synchronously", function()
  local Inline = assert(loadfile("lua/era/m/image/inline.lua"))()
  local bufnr = t:buffer()

  t.assert_error(function()
    Inline.new(bufnr, nil)
  end, "document should be a table", "missing document")
  t.assert_error(function()
    Inline.new(bufnr, {})
  end, "document.find_visible", "missing find_visible")
  t.assert_error(function()
    Inline.new(bufnr, { find_visible = function() end })
  end, "document.math_enabled", "missing math_enabled")
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

  t.assert_same({ width = 10, height = 5 }, size, "cell size")
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
  local bufnr = t:buffer()
  local provider = nil ---@type era.m.image.inline.IDocument|nil
  t:patch_table(package.loaded, "era.m.image.inline", {
    new = function(_, document)
      provider = document
    end,
  })

  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  document.attach(bufnr)

  t.assert_eq(document, provider, "document provider")
end)

t:test("a document keeps one inline renderer until it is disposed", function()
  local created = {} ---@type table[]
  t:patch_table(package.loaded, "era.m.image.inline", {
    new = function(bufnr)
      created[#created + 1] = { bufnr = bufnr }
      return created[#created]
    end,
  })
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()

  -- FileType fires again for a buffer that is still attached, e.g. after `:set filetype=markdown`.
  document.attach(41)
  document.attach(41)
  t.assert_eq(1, #created, "attached once")

  -- `:edit` or `:bdelete` unloaded the buffer, which disposed its renderer.
  created[1].disposed = true
  document.attach(41)
  t.assert_eq(2, #created, "attached anew")
end)

t:run()
