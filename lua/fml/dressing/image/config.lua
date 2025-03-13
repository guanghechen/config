---@class fml.dressing.image.config.env
---@field public name                   string
---@field public placeholders           boolean
---@field public remote                 boolean
---@field public supported              boolean
---@field public setup                  ?fun():nil
---@field public transform              ?fun(data: string): string

---@class fml.dressing.image.config.state
local config = {
  cache = vim.fn.stdpath("cache") .. "/fml/image",
  convert = {
    notify = true, -- show a notification on error
    ---@type fml.dressing.image.args
    mermaid = function()
      local theme = vim.o.background == "light" and "neutral" or "dark"
      return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-t", theme, "-s", "{scale}" }
    end,
    ---@type table<string, fml.dressing.image.args>
    magick = {
      default = { "{src}[0]", "-scale", "1920x1080>" }, -- default for raster images
      vector = { "-density", 192, "{src}[0]" }, -- used by vector images like svg
      math = { "-density", 192, "{src}[0]", "-trim" },
      pdf = { "-density", 192, "{src}[0]", "-background", "white", "-alpha", "remove", "-trim" },
    },
  },
  debug = {
    request = false,
    convert = false,
    placement = false,
  },
  doc = {
    enabled = true, -- enable image viewer for documents a treesitter parser must be available for the enabled languages.
    -- render the image inline in the buffer
    -- if your env doesn't support unicode placeholders, this will be disabled
    -- takes precedence over `opts.float` on supported terminals
    inline = true,
    float = true, -- render the image in a floating window only used if `opts.inline` is disabled
    max_width = 80,
    max_height = 40,
    ---@param lang                      string tree-sitter language
    ---@param type                      fml.dressing.image.Type image type
    ---@return nil
    ---@diagnostic disable-next-line: unused-local
    conceal = function(lang, type)
      -- only conceal math expressions
      return type == "math"
    end,
  },
  extnames = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".bmp",
    ".webp",
    ".tiff",
    ".heic",
    ".avif",
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",
    ".webm",
    ".pdf",
  },
  icons = {
    math = "󰪚 ",
    chart = "󰄧 ",
    image = " ",
  },
  img_dirs = { "img", "images", "assets", "static", "public", "media", "attachments" },
  math = {
    enabled = true, -- enable math expression rendering
    latex = {
      font_size = "Large", -- see https://www.sascha-frank.com/latex-font-size.html
      -- for latex documents, the doc packages are included automatically,
      -- but you can add more packages here. Useful for markdown documents.
      packages = { "amsmath", "amssymb", "amsfonts", "amscd", "mathtools" },
      tpl = [[
        \documentclass[preview,border=0pt,varwidth,12pt]{standalone}
        \usepackage{${packages}}
        \begin{document}
        ${header}
        { \${font_size} \selectfont
          \color[HTML]{${color}}
        ${content}}
        \end{document}]],
    },
    -- in the templates below, `${header}` comes from any section in your document,
    -- between a start/end header comment. Comment syntax is language-specific.
    typst = {
      tpl = [[
        #set page(width: auto, height: auto, margin: (x: 2pt, y: 2pt))
        #show math.equation.where(block: false): set text(top-edge: "bounds", bottom-edge: "bounds")
        #set text(size: 12pt, fill: rgb("${color}"))
        ${header}
        ${content}]],
    },
  },
  terminals = {
    {
      name = "kitty",
      supported = true,
      placeholders = true,
      env = {
        TERM = "kitty",
        KITTY_PID = true,
      },
    },
    {
      name = "ghostty",
      supported = true,
      placeholders = true,
      env = {
        TERM = "ghostty",
        GHOSTTY_BIN_DIR = true,
      },
    },
    {
      name = "wezterm",
      supported = true,
      placeholders = false,
      env = {
        TERM = "wezterm",
        WEZTERM_PANE = true,
        WEZTERM_EXECUTABLE = true,
        WEZTERM_CONFIG_FILE = true,
        GUANGHECHEN_WEZTERM = true,
      },
    },
    {
      name = "tmux",
      env = {
        TERM = "tmux",
        TMUX = true,
      },
      setup = function()
        pcall(vim.fn.system, { "tmux", "set", "-p", "allow-passthrough", "all" })
      end,
      transform = function(data)
        return ("\027Ptmux;" .. data:gsub("\027", "\027\027")) .. "\027\\"
      end,
    },
    {
      name = "zellij",
      supported = false,
      placeholders = false,
      env = {
        TERM = "zellij",
        ZELLIJ = true,
      },
    },
    {
      name = "ssh",
      remote = true,
      env = {
        SSH_CLIENT = true,
        SSH_CONNECTION = true,
      },
    },
  },
}

local SUPPORTED_EXTNAME_SET = eve.std.array.to_string_set(config.extnames) ---@type table<string, boolean>

---@class fml.dressing.image.config
---@field public state                  fml.dressing.image.config.state
---@field private _env                  fml.dressing.image.config.env|nil
local M = {}
M.state = config

---@param filename                      string
---@return boolean
function M.is_support(filename)
  return M.is_support_terminal() and M.is_support_file(filename)
end

---@param extname                       string
---@return boolean
function M.is_support_extname(extname)
  return SUPPORTED_EXTNAME_SET[extname] == true
end

---@param filename                      string
---@return boolean
function M.is_support_file(filename)
  local extname = eve.std.path.extname(filename) ---@type string
  return SUPPORTED_EXTNAME_SET[extname] == true
end

---@return boolean
function M.is_support_terminal()
  return M.resolve_env().supported
end

---@return fml.dressing.image.config.env
function M.resolve_env()
  if M._env ~= nil then
    return M._env
  end

  ---@type fml.dressing.image.config.env
  local env = {
    name = "",
    placeholders = false,
    remote = false,
    supported = false,
  }
  M._env = env

  for _, terminal in ipairs(config.terminals) do
    local matched = false ---@type boolean
    local override = os.getenv("GUANGHECHEN_" .. terminal.name:upper())
    if override then
      matched = override ~= "0" and override ~= "false"
    else
      for k, v in pairs(terminal.env) do
        local val = os.getenv(k)
        if val and (v == true or (type(v) == "string" and val:find(v))) then
          matched = true
          break
        end
      end
    end
    if matched then
      env.name = #env.name == 0 and terminal.name or (env.name .. "/" .. terminal.name)
      if type(terminal.supported) == "boolean" then
        env.supported = terminal.supported
      end
      if type(terminal.placeholders) == "boolean" then
        env.placeholders = terminal.placeholders
      end
      if type(terminal.remote) == "boolean" then
        env.remote = env.remote or terminal.remote
      end
      env.transform = terminal.transform or env.transform
      if terminal.setup then
        terminal.setup()
      end
    end
  end
  return env
end

return M
