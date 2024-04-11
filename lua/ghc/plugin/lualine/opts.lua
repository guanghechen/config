local function opts()
  local icons = require("lazyvim.config").icons
  local settings = require("ghc.core")
  local symbols = settings.symbols.status_line

  local colors = {
    user_bg = "#BD7BB8",
    user_fg = "#FFFFFF",
    main_bg = "#1C1D2A",
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
    local gitsigns = vim.b["gitsigns_status_dict"]
    if gitsigns then
      return {
        added = gitsigns.added,
        modified = gitsigns.changed,
        removed = gitsigns.removed,
      }
    end
  end

  local components = {
    separator = { -- use as section separators
      function()
        return "│"
      end,
      padding = 0,
      color = {
        fg = colors.main_bg,
        bg = colors.main_bg,
      },
    },
    separator_split = { -- use as section separators
      function()
        return "│"
      end,
      padding = 0,
    },
    separator_user = {
      function()
        return symbols.section_separator_left
      end,
      padding = 0,
      color = {
        fg = colors.user_bg,
      },
    },
    user = {
      function()
        local user = os.getenv("USER")
        return user
      end,
      padding = 1,
      color = {
        fg = colors.user_fg,
        bg = colors.user_bg,
      },
    },
    filename_status = {
      function()
        local function is_new_file()
          local filename = vim.fn.expand("%")
          return filename ~= "" and vim.bo.buftype == "" and vim.fn.filereadable(filename) == 0
        end

        local file_status = {}
        if vim.bo.readonly == true then
          table.insert(file_status, "[RO]")
        end
        if is_new_file() then
          table.insert(file_status, "[New]")
        end
        return #file_status > 0 and table.concat(file_status, "") or ""
      end,
      padding = { left = -1, right = 1 },
      cond = conditionals.has_comp_before,
    },
    cwd = {
      function()
        local name = vim.loop.cwd() or ""
        name = " " .. (name:match("([^/\\]+)[/\\]*$") or name) .. " "
        return (vim.o.columns > 85 and (symbols.cwd .. name)) or ""
      end,
    },
    tabwidth = {
      function()
        return symbols.tab .. vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })
      end,
      padding = 1,
    },
  }

  return {
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
        "mode",
      },
      lualine_b = {
        "branch",
        components.separator,
      },
      lualine_c = {
        LazyVim.lualine.root_dir(),
        {
          "diagnostics",
          symbols = {
            error = icons.diagnostics.Error,
            warn = icons.diagnostics.Warning,
            info = icons.diagnostics.Infor,
            hint = icons.diagnostics.Hint_alt,
          },
        },
        {
          "filetype",
          icon_only = true,
          separator = "",
          padding = { left = 1, right = 0 },
        },
        "filename",
        components.filename_status,
      },
      lualine_x = {
        "location",
        "%=",
        {
          function()
            return require("noice").api.status.command.get()
          end,
          cond = function()
            return package.loaded["noice"] and require("noice").api.status.command.has()
          end,
          color = LazyVim.ui.fg("Statement"),
        },
        {
          function()
            return require("noice").api.status.mode.get()
          end,
          cond = function()
            return package.loaded["noice"] and require("noice").api.status.mode.has()
          end,
          color = LazyVim.ui.fg("Constant"),
        },
        {
          function()
            return "  " .. require("dap").status()
          end,
          cond = function()
            return package.loaded["dap"] and require("dap").status() ~= ""
          end,
          color = LazyVim.ui.fg("Debug"),
        },
        {
          require("lazy.status").updates,
          cond = require("lazy.status").has_updates,
          color = LazyVim.ui.fg("Special"),
        },
        {
          "diff",
          symbols = {
            added = icons.git.added,
            modified = icons.git.modified,
            removed = icons.git.removed,
          },
          cond = conditionals.has_git,
          source = diff_source,
          colored = false,
          padding = { right = 1 },
        },
        "filesize",
      },
      lualine_y = {
        components.separator,
        {
          "encoding",
          fmt = string.upper,
          padding = { left = 1 },
          cond = conditionals.has_enough_room,
        },
        components.tabwidth,
        {
          "fileformat",
          symbols = {
            unix = "LF",
            dos = "CRLF",
            mac = "CR", -- Legacy macOS
          },
          padding = { left = 1, right = 1 },
        },
        "filetype",
      },
      lualine_z = {
        components.cwd,
      },
    },
  }
end

return opts
