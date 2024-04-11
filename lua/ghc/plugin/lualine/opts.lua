local settings = require("ghc.core")
local icons = {
  diagnostics = settings.icons.get("diagnostics", true),
  git = settings.icons.get("git", true),
  git_nosep = settings.icons.get("git"),
  misc = settings.icons.get("misc", true),
  ui = settings.icons.get("ui", true),
}
local symbols = settings.symbols.status_line
local colors = {
  userBg = "#BD7BB8",
  userFg = "#FFFFFF",
  pythonBg = "#343A56",
  mainBg = "#16161C",
}

local conditionals = {
  has_enough_room = function()
    return vim.o.columns > 100
  end,
  has_comp_before = function()
    return vim.bo.filetype ~= ""
  end,
  has_git = function()
    local gitdir = vim.fs.find(".git", {
      limit = 1,
      upward = true,
      type = "directory",
      path = vim.fn.expand("%:p:h"),
    })
    return #gitdir > 0
  end,
  is_python_file = function()
    return vim.api.nvim_get_option_value("filetype", { scope = "local" }) == "python"
  end,
}

local function diff_source()
  local gitsigns = vim.b.gitsigns_status_dict
  if gitsigns then
    return {
      added = gitsigns.added,
      modified = gitsigns.changed,
      removed = gitsigns.removed,
    }
  end
end

local function force_centering()
  return "%="
end

local function abbreviate_path(path)
  local home = settings.globals.home
  if path:find(home, 1, true) == 1 then
    path = "~" .. path:sub(#home + 1)
  end
  return path
end

local components = {
  separator = { -- use as section separators
    function()
      return "│"
    end,
    padding = 0,
    color = {
      fg = colors.mainBg,
      bg = colors.mainBg,
    },
  },
  separator_user = {
    function()
      return symbols.section_separator_left
    end,
    padding = 0,
    color = {
      fg = colors.userBg,
    },
  },
  separator_python = {
    function()
      return symbols.section_separator_right
    end,
    padding = 0,
    color = {
      fg = colors.pythonBg,
    },
    cond = function()
      return conditionals.has_enough_room() and conditionals.is_python_file()
    end,
  },
  user = {
    function()
      local user = os.getenv("USER")
      return user
    end,
    padding = 1,
    color = {
      fg = colors.userFg,
      bg = colors.userBg,
    },
  },
  filename = {
    function()
      local fullFilePath = vim.fn.expand("%:p")
      local filename = fullFilePath:match("^.+/(.+)$") -- 提取文件名部分
      return filename
    end,
    colored = true,
    icon_only = false,
    padding = { left = 1, right = 1 },
  },
  filename_status = {
    function()
      local function is_new_file()
        local filename = vim.fn.expand("%")
        return filename ~= "" and vim.bo.buftype == "" and vim.fn.filereadable(filename) == 0
      end

      local symbols = {}
      if vim.bo.modified then
        table.insert(symbols, "[+]")
      end
      if vim.bo.modifiable == false then
        table.insert(symbols, "[-]")
      end
      if vim.bo.readonly == true then
        table.insert(symbols, "[RO]")
      end
      if is_new_file() then
        table.insert(symbols, "[New]")
      end
      return #symbols > 0 and table.concat(symbols, "") or ""
    end,
    padding = { left = -1, right = 1 },
    cond = conditionals.has_comp_before,
  },
  file_location = {
    function()
      local cursorline = vim.fn.line(".")
      local cursorcol = vim.fn.virtcol(".")
      return string.format("%d·%d", cursorline, cursorcol)
    end,
  },
  cwd = {
    function()
      return icons.ui.FolderWithHeart .. abbreviate_path(vim.fs.normalize(vim.fn.getcwd()))
    end,
    color = {
      fg = "#A6ADC8",
      bg = nil, -- "#16161C",
    },
    cond = conditionals.has_enough_room,
  },
  lsp = {
    function()
      local buf_ft = vim.api.nvim_get_option_value("filetype", { scope = "local" })
      local clients = vim.lsp.get_active_clients()
      local lsp_lists = {}
      local available_servers = {}
      if next(clients) == nil then
        return icons.misc.NoActiveLsp -- No server available
      end
      for _, client in ipairs(clients) do
        local filetypes = client.config.filetypes
        local client_name = client.name
        if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
          -- Avoid adding servers that already exists.
          if not lsp_lists[client_name] then
            lsp_lists[client_name] = true
            table.insert(available_servers, client_name)
          end
        end
      end
      return next(available_servers) == nil and icons.misc.NoActiveLsp or string.format("%s[%s]", icons.misc.LspAvailable, table.concat(available_servers, ", "))
    end,
    color = nil,
    cond = conditionals.has_enough_room,
  },
  python_venv = {
    function()
      local function env_cleanup(venv)
        if string.find(venv, "/") then
          local final_venv = venv
          for w in venv:gmatch("([^/]+)") do
            final_venv = w
          end
          venv = final_venv
        end
        return venv
      end

      local venv = os.getenv("CONDA_DEFAULT_ENV")
      if venv then
        return icons.misc.PyEnv .. env_cleanup(venv)
      end
      venv = os.getenv("VIRTUAL_ENV")
      if venv then
        return icons.misc.PyEnv .. env_cleanup(venv)
      end
    end,
    color = {
      bg = colors.pythonBg,
    },
    cond = function()
      return conditionals.has_enough_room() and conditionals.is_python_file()
    end,
  },
  tabwidth = {
    function()
      return icons.ui.Tab .. vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })
    end,
    padding = 1,
  },
}

local opts = {
  options = {
    theme = "auto",
    component_separators = {
      left = symbols.component_separator_left,
      right = symbols.component_separator_right,
    },
    section_separators = {
      left = symbols.section_separator_left,
      right = symbols.section_separator_right,
    },
    globalstatus = true,
  },
  sections = {
    lualine_a = {
      components.user,
      components.separator_user,
      { "mode", colored = true, icon_only = false },
    },
    lualine_b = {
      -- { "filename", colored = true, icon_only = false },
      components.filename,
      components.filename_status,
      components.separator,
    },
    lualine_c = {
      {
        "branch",
        icon = icons.git_nosep.Branch,
        cond = conditionals.has_git,
      },
      {
        "diff",
        symbols = {
          added = icons.git.Add,
          modified = icons.git.Mod_alt,
          removed = icons.git.Remove,
        },
        cond = conditionals.has_git,
        source = diff_source,
        colored = false,
        padding = { right = 1 },
      },
      {
        force_centering,
      },
      {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        sections = { "error", "warn", "info", "hint" },
        symbols = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warning,
          info = icons.diagnostics.Information,
          hint = icons.diagnostics.Hint_alt,
        },
      },
      components.lsp,
    },
    lualine_x = {
      {
        "encoding",
        fmt = string.upper,
        padding = { left = 1 },
        cond = conditionals.has_enough_room,
      },
      {
        "fileformat",
        symbols = {
          unix = "LF",
          dos = "CRLF",
          mac = "CR", -- Legacy macOS
        },
        padding = { left = 1 },
      },
      components.tabwidth,
      "filetype",
    },
    lualine_y = {
      components.separator,
      components.cwd,
      components.separator_python,
      components.python_venv,
    },
    lualine_z = { components.file_location },
  },
}

return opts
