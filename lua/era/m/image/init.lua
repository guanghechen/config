local __module_name__ = "era.m.image" ---@type string

---@class era.m.image.__mods
local __mods = {
  Convert = "era.m.image.convert",
  doc = "era.m.image.doc",
  Image = "era.m.image.image",
  inline = "era.m.image.inline",
  Placement = "era.m.image.placement",
  state = "era.m.image.state",
  terminal = "era.m.image.terminal",
}

---@class era.m.image
---@field public __mods                 era.m.image.__mods
---@field public Convert                era.m.image.Convert
---@field public dressing               fun(): nil
---@field public doc                    era.m.image.doc
---@field public Image                  era.m.image.Image
---@field public inline                 era.m.image.inline
---@field public Placement              era.m.image.Placement
---@field public state                  era.m.image.state
---@field public terminal               era.m.image.terminal
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@return nil
function M.dressing()
  -- Graphics-protocol image/math preview is only enabled on macOS by choice.
  if not stl.env.IS_OSX then
    return
  end

  local state = require("era.m.image.state")
  if not state.is_support_terminal() then
    return
  end

  if state.did_setup then
    return
  end

  if stl.env.IS_TMUX then
    -- Popups have no owning pane to enable passthrough for.
    local pane = vim.env.TMUX_PANE
    if pane == nil then
      return
    end

    -- `on` can discard uploads during tmux redraws or while the pane is hidden.
    local result = vim
      .system({ "tmux", "set-option", "-p", "-t", pane, "allow-passthrough", "all" }, { text = true, timeout = 1000 })
      :wait()
    if result.code ~= 0 then
      local message = ("tmux exited with %d: %s"):format(result.code, result.stderr or "")
      stl.reporter.warn({ from = __module_name__, subject = "tmux image passthrough", message = message })
      return
    end
  end

  state.did_setup = true

  local group = stl.nvim.fn.augroup("era.image_dressing")
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    callback = function(e)
      vim.schedule(function()
        local Placement = package.loaded["era.m.image.placement"]
        if Placement ~= nil then
          Placement.clean(e.buf)
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "ExitPre" }, {
    group = group,
    once = true,
    callback = function()
      local Placement = package.loaded["era.m.image.placement"]
      if Placement ~= nil then
        Placement.clean()
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "*" .. table.concat(state.data.extnames, ",*"),
    group = group,
    callback = function(e)
      local bufnr = e.buf
      local filename = vim.api.nvim_buf_get_name(bufnr)
      if not state.is_support_file(filename) then
        local lines = {
          "# Image viewer",
          "- **file**: `" .. filename .. "`",
          "- unsupported image format",
        }
        vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
        vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
      else
        local Placement = require("era.m.image.placement")
        vim.api.nvim_set_option_value("filetype", "image", { buf = bufnr })
        vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
        Placement.new(bufnr, filename, { conceal = true, auto_resize = true })
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    pattern = "*" .. table.concat(state.data.extnames, ",*"),
    group = group,
    callback = function(e)
      vim.api.nvim_set_option_value("modified", false, { buf = e.buf })
    end,
  })

  -- This setup is deferred past startup, which has already read the files it was given as text, so an
  -- unchanged image buffer among them is read again through the viewer.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local filename = vim.api.nvim_buf_get_name(bufnr):lower() ---@type string
    local image = false ---@type boolean
    for _, extname in ipairs(state.data.extnames) do
      image = image or filename:sub(-#extname) == extname:lower()
    end
    if
      image
      and vim.api.nvim_buf_is_loaded(bufnr)
      and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == ""
      and not vim.api.nvim_get_option_value("modified", { buf = bufnr })
    then
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("edit")
      end)
    end
  end

  if state.data.doc.enabled then
    local queries = vim.api.nvim_get_runtime_file("queries/*/images.scm", true)
    local supported_lang_set = {} ---@type table<string, true>
    for _, query in ipairs(queries) do
      local lang = query:match("queries/(.-)/images%.scm") ---@type string|nil
      if lang then
        supported_lang_set[lang] = true
      end
    end

    ---@param bufnr                      integer
    ---@return boolean
    local function is_doc_supported(bufnr)
      if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return false
      end

      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
      -- Resolve aliases without loading the parser stack.
      local lang = require("vim.treesitter.language").get_lang(filetype) ---@type string|nil
      return lang ~= nil and supported_lang_set[lang] == true
    end

    ---@param bufnr                      integer
    ---@return nil
    local function attach_doc(bufnr)
      if not is_doc_supported(bufnr) then
        return
      end

      vim.schedule(function()
        if is_doc_supported(bufnr) then
          require("era.m.image.doc").attach(bufnr)
        end
      end)
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(e)
        attach_doc(e.buf)
      end,
    })

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      attach_doc(bufnr)
    end
  end
end

return M
