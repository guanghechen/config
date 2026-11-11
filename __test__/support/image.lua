---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.image" ---@type string

-- The globals the image modules read, for the inline renderer and its placements, for conversions and for the dressing
-- hooks. Conversions run the executables a suite writes, not ImageMagick and its peers; placements load over doubles of
-- the image, state and terminal modules.

local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local harness = require("__test__.support.harness")

local M = {}

---Declares the globals placements and the inline renderer read: images are shown (`dressing_image` is on) and no
---observed value ever changes.
---@param t                             __test__.support.Harness
---@return nil
function M.with_inline(t)
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
end

---An image double for `/images/a.png` under the id 7, already sent, that is ready and failed as `props` says and keeps
---the placements it shows.
---@param props                         { ready: boolean, failed?: boolean }
---@return table
function M.fake_image(props)
  local image = { id = 7, src = "/images/a.png", file = "/images/a.png", sent = true, placements = {} }
  ---@return boolean
  function image:ready()
    return props.ready
  end
  ---@return boolean
  function image:failed()
    return props.failed == true
  end
  ---@return table
  function image:latest()
    return self
  end
  ---@param placement                   { id: integer }
  ---@return nil
  function image:place(placement)
    self.placements[placement.id] = placement
  end
  ---@param id                          integer
  ---@return nil
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

---Loads a fresh `era.m.image.placement`, which `require` returns until the case ends. It runs over doubles: an image
---module whose `new` returns `image`, or calls it when it is a function; a state that fits every image in 3 by 2 cells;
---a terminal that drops every request.
---@param t                             __test__.support.Harness
---@param image                         table|fun(src: string): table
---@return table
function M.load_placement(t, image)
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

---A file buffer of `lines`, none by default, shown unmodified in the current window until the case ends.
---@param t                             __test__.support.Harness
---@param lines                         ?string[]
---@return integer
function M.shown_buf(t, lines)
  -- A file buffer, like the viewer's, tracks `modified`.
  local bufnr = t:buffer(lines or {}, { scratch = false, current = true })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  return bufnr
end

---Declares the globals conversions read, over the native library in a terminal without a graphics protocol outside
---tmux, and replaces the terminal module with one of 1000 by 1000 pixels in 100 by 50 cells that hands each request to
---`request`. Conversions cache their files in a temporary directory and find executables in the returned directory
---first. All of it lasts until the suite (inside a case, the case) ends.
---@param t                             __test__.support.Harness
---@param request                       ?fun(opts: table): nil
---@return string bin
---@return string path_env              The PATH before.
function M.with_conversion(t, request)
  bootstrap.with_native(t)
  bootstrap.with_runtime(t, {
    dot = {
      path = {
        join = function(left, right)
          return yoz.path.join(left, right, true, "/")
        end,
        normalize = function(path)
          return yoz.path.normalize(path, true, "/")
        end,
      },
    },
    stl = {
      c = { Proc = require("stl.c.proc") },
      env = {
        IS_GHOSTTY = false,
        IS_KITTY = false,
        IS_TMUX = false,
        IS_WIN = false,
        mkdirs = function(path)
          vim.fn.mkdir(path, "p")
        end,
      },
      table = require("stl.table"),
    },
  })

  local bin = t:tempdir() ---@type string
  local path_env = vim.env.PATH ---@type string
  vim.env.PATH = bin .. ":" .. path_env
  t:defer(function()
    vim.env.PATH = path_env
  end)

  t:patch_table(package.loaded, "era.m.image.terminal", {
    request = request or function() end,
    size = function()
      return { width = 1000, height = 1000, columns = 100, rows = 50, cell_width = 10, cell_height = 20, scale = 1 }
    end,
  })
  t:patch_table(require("era.m.image.state").data, "tmpdir", t:tempdir())
  return bin, path_env
end

---Writes the shell script `lines` as the executable `name` in `dir`.
---@param dir                           string
---@param name                          string
---@param lines                         string[]
---@return nil
function M.executable(dir, name, lines)
  fs.write(dir .. "/" .. name, lines)
  vim.fn.setfperm(dir .. "/" .. name, "rwxr-xr-x")
end

---Runs `conversion` and waits until it is done.
---@param conversion                    era.m.image.Convert
---@return nil
function M.finish(conversion)
  conversion:run()
  harness.wait_until(function()
    return conversion:done()
  end, 5000, "conversion")
end

---Declares the globals `era.m.image.dressing` reads on macOS outside tmux, with `observe` as `stl.fn.observe`, and an
---image state, which it returns, that supports the terminal and every file, with documents enabled when `doc` is.
---@param t                             __test__.support.Harness
---@param doc                           ?boolean
---@param observe                       ?fun(observable: any, callback: fun()): nil
---@return table
function M.with_dressing(t, doc, observe)
  local state = {
    data = {
      doc = { enabled = doc == true },
      extnames = { ".png" },
    },
    did_setup = false,
    is_support_file = function()
      return true
    end,
    is_support_terminal = function()
      return true
    end,
  }
  t:patch_global("stl", {
    env = { IS_OSX = true },
    fn = { observe = observe or function() end },
    nvim = { fn = {
      augroup = function()
        return 1
      end,
    } },
  })
  t:patch_global("dot", { context = { theme = {} } })
  t:patch_table(package.loaded, "era.m.image.state", state)
  return state
end

return M
