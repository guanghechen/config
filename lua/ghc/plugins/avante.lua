local Select = require("fml.ux.select")

local AI_PROVIDER_MAP = {
  aoai = "azure",
  copilot = "copilot",
  deepseek = "deepseek",
}

---@class ghc.plugins.avante.file_selector.IParams
---@field public title                  string
---@field public filepaths              string[]
---@field public handler                fun(filepaths: string[]|nil): nil

---@return fun(params: ghc.plugins.avante.file_selector.IParams): nil
local function get_file_selector()
  local context = eve.state.select.select_avante
  local _on_choice = eve.std.fn.noop ---@type fun(items: fml.ux.select.IItem[] | nil): nil
  local _filepaths = {} ---@type string[]
  local _winnr = nil ---@type integer|nil
  local _confirmed = false ---@type boolean
  local _select ---@type fml.ux.Select

  eve.state.observe({
    eve.state.select.select_avante.excludes,
    eve.state.select.select_avante.flag_case_sensitive,
    eve.state.select.select_avante.flag_exclude,
    eve.state.select.select_avante.flag_fuzzy,
    eve.state.select.select_avante.flag_gitignore,
    eve.state.select.select_avante.flag_regex,
  }, function()
    if _select ~= nil then
      _select:mark_data_dirty()
    end
  end, true)

  ---@class ghc.plugins.avante.file_selector.actions
  local actions = {
    toggle_case_sensitive = function()
      local flag = eve.state.select.select_avante.flag_case_sensitive:snapshot() ---@type boolean
      eve.state.select.select_avante.flag_case_sensitive:next(not flag)
    end,
    toggle_flag_exclude = function()
      local flag = eve.state.select.select_avante.flag_exclude:snapshot() ---@type boolean
      eve.state.select.select_avante.flag_exclude:next(not flag)
    end,
    toggle_flag_fuzzy = function()
      local flag = eve.state.select.select_avante.flag_fuzzy:snapshot() ---@type boolean
      eve.state.select.select_avante.flag_fuzzy:next(not flag)
    end,
    ---@return nil
    toggle_flag_gitignore = function()
      local flag = eve.state.select.select_avante.flag_gitignore:snapshot() ---@type boolean
      eve.state.select.select_avante.flag_gitignore:next(not flag)
    end,
    toggle_flag_regex = function()
      local flag = eve.state.select.select_avante.flag_regex:snapshot() ---@type boolean
      eve.state.select.select_avante.flag_regex:next(not flag)
    end,
    ---@return nil
    toggle_flag_selected = function()
      local flag = eve.state.select.select_avante.flag_selected:snapshot() ---@type boolean
      eve.state.select.select_avante.flag_selected:next(not flag)
    end,
  }

  ---@type eve.t.ux.widget.IRawStatuslineItem[]
  local statusline_items = {
    {
      type = "flag",
      desc = "find: toggle selected",
      symbol = eve.icon.symbols.flag_selected,
      state = eve.state.select.select_avante.flag_selected,
      callback = actions.toggle_flag_selected,
    },
    {
      type = "flag",
      desc = "find: toggle exclude",
      symbol = eve.icon.symbols.flag_exclude,
      state = eve.state.select.select_avante.flag_exclude,
      callback = actions.toggle_flag_exclude,
    },
    {
      type = "flag",
      desc = "find: toggle gitignore",
      symbol = eve.icon.symbols.flag_gitignore,
      state = eve.state.select.select_avante.flag_gitignore,
      callback = actions.toggle_flag_gitignore,
    },
    {
      type = "flag",
      desc = "select: toggle flag fuzzy",
      symbol = eve.icon.symbols.flag_fuzzy,
      state = eve.state.select.select_avante.flag_fuzzy,
      callback = actions.toggle_flag_fuzzy,
    },
    {
      type = "flag",
      desc = "find: toggle case sensitive",
      symbol = eve.icon.symbols.flag_case_sensitive,
      state = eve.state.select.select_avante.flag_case_sensitive,
      callback = actions.toggle_case_sensitive,
    },
    {
      type = "flag",
      desc = "select: toggle flag regex",
      symbol = eve.icon.symbols.flag_regex,
      state = eve.state.select.select_avante.flag_regex,
      callback = actions.toggle_flag_regex,
    },
  }

  _select = Select.new({
    dimension = {
      height = 3,
      max_height = 0.8,
      max_width = 0.8,
      width = 80,
    },
    case_sensitive = context.flag_case_sensitive,
    flag_regex = context.flag_regex,
    flag_fuzzy = context.flag_fuzzy,
    flag_selected = context.flag_selected,
    frecency = eve.state.frecency.files,
    input = context.input,
    input_history = context.input_history,
    multiple = true,
    preview_enabled = false,
    extend_preset_keymaps = false,
    permanent = true,
    statusline_items = statusline_items,
    title = "(Avante) Add a file",
    provider = {
      fetch_data = function()
        local width = 0 ---@type integer
        local items = {} ---@type fml.ux.select.IItem[]
        local cwd = eve.path.cwd() ---@type string
        for index, filepath in ipairs(_filepaths) do
          local uuid = tostring(index) ---@type string
          local text = filepath ---@type string
          local icon = "" ---@type string
          local icon_hl = nil ---@type string|nil

          local absolute_filepath = eve.path.join(cwd, filepath) ---@type string
          if vim.uv.fs_stat(absolute_filepath) and vim.uv.fs_stat(absolute_filepath).type == "directory" then
            icon = eve.icon.filetype.Folder
            icon_hl = "MiniIconsBlue"
          else
            icon, icon_hl = eve.fn.fileicon(filepath)
          end

          local data = { filepath = filepath, icon = icon, icon_hl = icon_hl }
          local select_item = { uuid = uuid, text = text, data = data } ---@type fml.ux.select.IItem
          width = width < #text and #text or width ---@type integer
          items[#items + 1] = select_item
        end

        vim.schedule(function()
          _select:change_dimension({
            height = #items + 3,
            max_height = math.min(math.floor(vim.o.lines * 0.8), 40),
            max_width = 0.8,
            width = math.max(60, width + 10),
          })
        end)
        return { items = items }
      end,
      render_item = function(item, match)
        local icon_width = string.len(item.data.icon .. " ") ---@type integer
        local text = item.data.icon .. " " .. item.data.filepath ---@type string

        if item.data.lnum ~= nil and item.data.col ~= nil then
          text = text .. ":" .. item.data.lnum .. ":" .. item.data.col
        end

        ---@type eve.t.IHighlightInline[]
        local highlights = { { coll = 0, colr = icon_width, hlname = item.data.icon_hl } }
        for _, piece in ipairs(match.matches) do
          ---@type eve.t.IHighlightInline
          local highlight = { coll = piece.l + icon_width, colr = piece.r + icon_width, hlname = "f_us_main_match" }
          table.insert(highlights, highlight)
        end
        return text, highlights
      end,
    },
    on_close = function()
      if not _confirmed then
        _confirmed = true
        _on_choice(nil)
      end

      if _winnr ~= nil and vim.api.nvim_win_is_valid(_winnr) then
        vim.api.nvim_tabpage_set_win(0, _winnr)
      end
    end,
    on_confirm = function(widget, items_selected)
      _confirmed = true
      _on_choice(items_selected)

      widget:close()
      if _winnr ~= nil and vim.api.nvim_win_is_valid(_winnr) then
        vim.api.nvim_tabpage_set_win(0, _winnr)
      end
    end,
  })

  ---@param params                      ghc.plugins.avante.file_selector.IParams
  ---@return nil
  local function file_selector(params)
    local handler = params.handler ---@type fun(filepaths: string[]|nil): nil
    -- _filepaths = resolve_filepaths(params.filepaths) ---@type string[]
    _filepaths = params.filepaths ---@type string[]
    _select:change_input_title(params.title)

    _on_choice = function(items)
      if items == nil then
        handler(nil)
      else
        local filepaths_selected = {} ---@type string[]
        for _, item in ipairs(items) do
          table.insert(filepaths_selected, item.data.filepath)
        end
        handler(filepaths_selected)
      end
    end

    _confirmed = false
    _winnr = vim.api.nvim_get_current_win()

    _select:mark_data_dirty()
    _select:show()
  end
  return file_selector
end

return {
  "avante.nvim",
  build = eve.env.IS_WIN and "pwsh -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource true"
    or "make BUILD_FROM_SOURCE=true",
  cmd = {
    "AvanteAsk",
    "AvanteChat",
    "AvanteClear",
    "AvanteEdit",
  },
  keys = {
    "<leader>aa",
    "<leader>ae",
    "<leader>ar",
  },
  dependencies = {
    "plenary.nvim",
    "nui.nvim",
    "nvim-cmp",
    "mini.icons",
    "copilot.lua",
    "render-markdown.nvim",
  },
  opts = function()
    local ai_provider = eve.state.flight.ai_provider:snapshot() ---@type eve.e.AiProvider
    local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot" ---@type string
    return {
      azure = {
        endpoint = vim.env.AZURE_OPENAI_ENDPOINT,
        deployment = "gpt-4o",
        model = "gpt-4o",
        api_version = "2024-08-01-preview",
      },
      copilot = {
        model = "claude-3.7-sonnet",
      },
      vendors = {
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          model = "deepseek-coder",
        },
      },
      web_search_engine = {
        provider = "google",
      },

      provider = provider_name,
      auto_suggestions_provider = "copilot",

      ------------------------------------------------------------------------------------------------

      behaviour = {
        auto_apply_diff_after_generation = false,
        auto_focus_sidebar = true,
        auto_suggestions = false,
        auto_suggestions_respect_ignore = true,
        auto_set_highlight_group = false,
        enable_token_counting = false,
        enable_cursor_planning_mode = false,
        jump_result_buffer_on_finish = true,
        minimize_diff = true,
        use_cwd_as_project_root = true,
      },

      file_selector = {
        provider = get_file_selector(),
        provider_opts = {
          get_filepaths = function(params)
            local cwd = eve.path.cwd() ---@type string
            local selected_filepaths = params.selected_filepaths ---@type string[]

            local workspace = eve.path.workspace() ---@type string
            local flag_exclude = eve.state.select.select_avante.flag_exclude:snapshot() ---@type boolean
            local flag_gitignore = eve.state.select.select_avante.flag_gitignore:snapshot() ---@type boolean
            local excludes = flag_exclude and eve.state.select.select_avante.excludes:snapshot() or {} ---@type string[]

            ---@type string[]
            local filepaths = eve.oxi.find({
              workspace = workspace,
              cwd = cwd,
              flag_case_sensitive = false,
              flag_gitignore = flag_gitignore,
              flag_regex = false,
              search_pattern = "",
              search_paths = "",
              exclude_patterns = table.concat(excludes, ","),
            })
            table.sort(filepaths)

            return vim
              .iter(filepaths)
              :filter(function(filepath)
                return not vim.tbl_contains(selected_filepaths, filepath)
              end)
              :totable()
          end,
        },
      },

      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",
        sidebar = {
          add_file = "@",
          apply_all = "A",
          apply_cursor = "a",
          close = { "<C-a>q", "<D-q>", "<M-q>" },
          close_from_input = {
            normal = "<C-a>q",
            insert = "<C-a>q",
          },
          edit_user_request = "e",
          remove_file = "d",
          retry_user_request = "r",
          reverse_switch_windows = "<S-Tab>",
          switch_windows = "<Tab>",
        },
        files = {
          add_current = "<leader>ab", -- Add current buffer to selected files
        },
        submit = {
          normal = "<CR>",
          insert = "<C-a>s",
        },
        cancel = {
          normal = { "<C-c>", "q" },
          insert = { "<C-c>" },
        },
        suggestion = {
          accept = "<C-cr>",
          next = "<C-j>",
          prev = "<C-k>",
          dismiss = "<esc>",
        },
      },
      windows = {
        ask = {
          floating = false,
          start_insert = false,
          border = "rounded",
          focus_on_apply = "theirs",
        },
        edit = {
          border = "rounded",
          start_insert = false, -- Start insert mode when opening the edit window
        },
      },
    }
  end,
  config = function(_, opts)
    package.loaded["dressing.nvim"] = {}

    require("avante").setup(opts)
    eve.state.observe({ eve.state.flight.ai_provider }, function()
      local ai_provider = eve.state.flight.ai_provider:snapshot()
      local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot"
      vim.cmd("AvanteSwitchProvider " .. provider_name)
    end, true)
  end,
}
