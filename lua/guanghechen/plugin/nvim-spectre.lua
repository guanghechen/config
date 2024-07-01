local function get_build_cmd()
  if not vim.fn.executable("cargo") then
    return ""
  end

  if fml.os.is_windows() then
    return "./build.ps1"
  end

  return "./build.sh"
end

return {
  "guanghechen/mirror",
  branch = "nvim@nvim-spectre", -- "alexghergh/nvim-tmux-navigation",
  commit = "13fed636bc71cbe54e5ece5feeb484fb324e353a",
  name = "nvim-spectre",
  main = "spectre",
  build = get_build_cmd(),
  enabled = vim.fn.executable("cargo") == 1,
  opts = function()
    local flag_case_sensitive = ghc.context.search.flag_case_sensitive:get_snapshot() ---@type boolean
    local rg_options = { "hidden" }
    local oxi_options = {}

    if not flag_case_sensitive then
      table.insert(rg_options, "ignore-case")
      table.insert(oxi_options, "ignore-case")
    end

    return {
      color_devicons = true,
      open_cmd = "noswapfile $tabnew",
      live_update = false, -- auto execute search again when you write to any file in vim
      lnum_for_results = true, -- show line number for search/replace results
      line_sep_start = "┌-----------------------------------------",
      result_padding = "¦  ",
      -- stylua: ignore
      line_sep       = "└-----------------------------------------",
      highlight = {
        ui = "String",
        replace = "ghc_spectre_replace",
        filedirectory = "ghc_spectre_filedirectory",
        filename = "ghc_spectre_filename",
        search = "ghc_spectre_search",
      },
      mapping = {
        ["tab"] = {
          map = "<Tab>",
          cmd = "<cmd>lua require('spectre').tab()<cr>",
          desc = "next query",
        },
        ["shift-tab"] = {
          map = "<S-Tab>",
          cmd = "<cmd>lua require('spectre').tab_shift()<cr>",
          desc = "previous query",
        },
        ["toggle_line"] = {
          map = "dd",
          cmd = "<cmd>lua require('spectre').toggle_line()<CR>",
          desc = "toggle item",
        },
        ["enter_file"] = {
          map = "<cr>",
          cmd = "<cmd>lua require('spectre.actions').select_entry()<CR>",
          desc = "open file",
        },
        ["send_to_qf"] = {
          map = "<c-q>",
          cmd = "<cmd>lua require('spectre.actions').send_to_qf()<CR>",
          desc = "send all items to quickfix",
        },
        ["replace_cmd"] = {
          map = "<leader>r:",
          cmd = "<cmd>lua require('spectre.actions').replace_cmd()<CR>",
          desc = "input replace command",
        },
        ["show_option_menu"] = {
          map = "<leader>ro",
          cmd = "<cmd>lua require('spectre').show_options()<CR>",
          desc = "show options",
        },
        ["run_current_replace"] = {
          map = "<leader>rc",
          cmd = "<cmd>lua require('spectre.actions').run_current_replace()<CR>",
          desc = "replace current line",
        },
        ["run_replace"] = {
          map = "<leader>r<cr>",
          cmd = "<cmd>lua require('spectre.actions').run_replace()<CR>",
          desc = "replace all",
        },
        ["change_view_mode"] = {
          map = "<leader>rv",
          cmd = "<cmd>lua require('spectre').change_view()<CR>",
          desc = "change result view mode",
        },
        ["change_replace_sed"] = {
          map = "<leader>rts",
          cmd = "<cmd>lua require('spectre').change_engine_replace('sed')<CR>",
          desc = "use sed to replace",
        },
        ["change_replace_oxi"] = {
          map = "<leader>rto",
          cmd = "<cmd>lua require('spectre').change_engine_replace('oxi')<CR>",
          desc = "use oxi to replace",
        },
        ["toggle_live_update"] = {
          map = "<leader>rtu",
          cmd = "<cmd>lua require('spectre').toggle_live_update()<CR>",
          desc = "update when vim writes to file",
        },
        ["toggle_ignore_case"] = {
          map = "<leader>rtI",
          cmd = "<cmd>lua require('guanghechen.core.action.replace').toggle_case_sensitive()<CR>",
          desc = "toggle ignore case",
        },
        ["toggle_ignore_hidden"] = {
          map = "<leader>rtH",
          cmd = "<cmd>lua require('spectre').change_options('hidden')<CR>",
          desc = "toggle search hidden",
        },
        ["resume_last_search"] = {
          map = "<leader>rl",
          cmd = "<cmd>lua require('spectre').resume_last_search()<CR>",
          desc = "repeat last search",
        },
        ["select_template"] = {
          map = "<leader>rp",
          cmd = "<cmd>lua require('spectre.actions').select_template()<CR>",
          desc = "pick template",
        },
      },
      find_engine = {
        -- rg is map with finder_cmd
        ["rg"] = {
          cmd = "rg",
          -- default args
          args = {
            "--multiline",
            "--hidden",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
          },
          options = {
            ["ignore-case"] = {
              icon = "[I]",
              value = "--ignore-case",
              desc = "ignore case",
            },
            ["hidden"] = {
              icon = "[H]",
              value = "--hidden",
              desc = "hidden file",
            },
            -- you can put any rg search option you want here it can toggle with show_option function
          },
        },
      },
      replace_engine = {
        ["sed"] = {
          cmd = "sed",
          args = { "-E" },
          options = {
            ["ignore-case"] = {
              icon = "[I]",
              value = "--ignore-case",
              desc = "ignore case",
            },
          },
        },
        ["oxi"] = {
          cmd = "oxi",
          args = {},
          options = {
            ["ignore-case"] = {
              icon = "[I]",
              value = "i",
              desc = "ignore case",
            },
          },
        },
      },
      default = {
        find = {
          --pick one of item in find_engine
          cmd = "rg",
          options = rg_options,
        },
        replace = {
          --pick one of item in replace_engine
          cmd = "oxi",
          options = oxi_options,
        },
      },
      replace_vim_cmd = "cdo",
      is_open_target_win = true, --open file on opener window
      is_insert_mode = false, -- start open panel on is_insert_mode
      is_block_ui_break = false, -- mapping backspace and enter key to avoid ui break
      open_template = {
        -- an template to use on open function
        -- see the 'custom function' section below to learn how to configure the template
        -- { search_text = 'text1', replace_text = '', path = "" }
      },
    }
  end,
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}
