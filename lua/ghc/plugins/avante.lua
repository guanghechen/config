local __module_name__ = "ghc.plugins.avante" ---@type string

---@class ghc.plugins.avante.file_selector.Item
---@field public id                     string
---@field public title                  string

---@class ghc.plugins.avante.file_selector.IParams
---@field public title                  string
---@field public items                  ghc.plugins.avante.file_selector.Item[]
---@field public default_item_id        string | nil
---@field public provider_opts          table | nil
---@field public on_select              fun(item_ids: string[] | nil): nil
---@field public selected_item_ids      string[] | nil
---@field public get_preview_content    fun(item_id: string): (string, string) | nil

local AI_PROVIDER_MAP = {
  aoai = "azure",
  copilot = "copilot",
  deepseek = "deepseek",
}

local o_flag_foldempty = std.Observable.from_value(true)
local o_flag_fuzzy = eve.context.select.select_avante.flag_fuzzy
local o_flag_regex = eve.context.select.select_avante.flag_regex
local o_flag_case_sensitive = eve.context.select.select_avante.flag_case_sensitive
local o_flag_selected = eve.context.select.select_avante.flag_selected
local o_flag_viewtype = std.Observable.from_value("tree")
local o_input = eve.context.select.select_avante.input
local o_input_history = eve.context.select.select_avante.input_history

local _on_choice = std.fn.noop ---@type fun(items: eve.ux.select.IItem[] | nil): nil
local _filepaths = {} ---@type string[]
local _winnr = nil ---@type integer|nil
local _confirmed = false ---@type boolean

local picker = eve.ux.picker.FiletreeComposer.new({
  name = string.format("%s -- %s", __module_name__, "file_selector"),
  permanent = true,
  title = "(Avante) Add a file",
  preview = false,
  width = 100,

  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_case_sensitive,
  flag_selected = o_flag_selected,
  finder_input = o_input,
  finder_input_history = o_input_history,
  frecency = eve.context.frecency.files,
  flag_foldempty = o_flag_foldempty,
  flag_viewtype = o_flag_viewtype,
  on_confirm = function(self, selected_filepaths)
    _confirmed = true
    _on_choice(selected_filepaths)

    self:close()
    if _winnr ~= nil and vim.api.nvim_win_is_valid(_winnr) then
      vim.api.nvim_tabpage_set_win(0, _winnr)
    end
  end,
  on_closed = function()
    if not _confirmed then
      _confirmed = true
      _on_choice(nil)
    end

    if _winnr ~= nil and vim.api.nvim_win_is_valid(_winnr) then
      vim.api.nvim_tabpage_set_win(0, _winnr)
    end
  end,
})

---@param params                      ghc.plugins.avante.file_selector.IParams
---@return nil
local function file_selector_provider(params)
  local handler = params.on_select ---@type fun(item_ids: string[] | nil): nil

  _filepaths = {} ---@type string[]
  for _, item in ipairs(params.items) do
    table.insert(_filepaths, item.id)
  end

  _on_choice = function(selected_filepaths)
    handler(selected_filepaths)
  end

  _confirmed = false
  _winnr = vim.api.nvim_get_current_win()

  picker:reset_filepaths(std.path.cwd(), _filepaths, false)
  picker:focus()
end

local selector_provider_opts = {
  get_filepaths = function(params)
    local cwd = std.path.cwd() ---@type string
    local selected_filepaths = params.selected_filepaths ---@type string[]

    local workspace = std.path.workspace() ---@type string
    local flag_exclude = eve.context.select.select_avante.flag_exclude:snapshot() ---@type boolean
    local flag_gitignore = eve.context.select.select_avante.flag_gitignore:snapshot() ---@type boolean
    local excludes = flag_exclude and eve.context.select.select_avante.excludes:snapshot() or {} ---@type string[]

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
}

return {
  "avante.nvim",
  build = std.env.IS_WIN and "pwsh -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource true"
    or "make BUILD_FROM_SOURCE=true",
  cmd = {
    "AvanteAsk",
    "AvanteChat",
    "AvanteClear",
    "AvanteEdit",
  },
  keys = {
    "<leader>aa",
    "<leader>ab",
    "<leader>ae",
    "<leader>ar",
  },
  dependencies = {
    "blink.cmp",
    "plenary.nvim",
    "nui.nvim",
    "nvim-treesitter",
    "copilot.lua",
    "render-markdown.nvim",
  },
  opts = function()
    local ai_provider = eve.context.flight.ai_provider:snapshot() ---@type std.e.AiProvider
    local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot" ---@type string
    return {
      debug = false,
      mode = "agentic",
      -- mode = "legacy",
      provider = provider_name,
      providers = {
        azure = {
          endpoint = vim.env.AZURE_OPENAI_ENDPOINT,
          deployment = vim.env.AZURE_OPENAI_DEPLOYMENT,
          model = vim.env.AZURE_OPENAI_MODEL,
          api_key_name = "AZURE_OPENAI_API_KEY",
          api_version = vim.env.AZURE_OPENAI_API_VERSION,
        },
        copilot = {
          model = "claude-sonnet-4",
        },
        aoai2 = {
          __inherited_from = "azure",
          deployment = vim.env.AZURE_OPENAI_O4_MINI_DEPLOYMENT,
          model = vim.env.AZURE_OPENAI_O4_MINI_MODEL,
          endpoint = vim.env.AZURE_OPENAI_O4_MINI_ENDPOINT,
          api_key_name = "AZURE_OPENAI_O4_MINI_API_KEY",
          api_version = vim.env.AZURE_OPENAI_O4_MINI_API_VERSION,
        },
        claude4 = {
          __inherited_from = "copilot",
          model = "claude-sonnet-4",
        },
        claude3_7 = {
          __inherited_from = "copilot",
          model = "claude-3.7-sonnet",
        },
        claude3_5 = {
          __inherited_from = "copilot",
          model = "claude-3.5-sonnet",
        },
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          model = "deepseek-coder",
        },
      },
      web_search_engine = {
        provider = "tavily",
        proxy = vim.env.https_proxy or vim.env.HTTPS_PROXY,
      },

      ------------------------------------------------------------------------------------------------

      behaviour = {
        auto_apply_diff_after_generation = false,
        auto_approve_tool_permissions = {
          "create",
          "ls",
          "replace_in_file",
          "str_replace",
          "undo_edit",
          "update_todo_status",
          "view",
          "write_to_file",
        },
        auto_check_diagnostics = true,
        auto_focus_on_diff_view = false,
        auto_focus_sidebar = true,
        auto_suggestions = false,
        auto_suggestions_respect_ignore = true,
        auto_set_highlight_group = false,
        auto_set_keymaps = true,
        enable_token_counting = true,
        jump_result_buffer_on_finish = false,
        minimize_diff = true,
        support_paste_from_clipboard = false,
        use_cwd_as_project_root = true,
      },

      selector = {
        provider = file_selector_provider,
        provider_opts = selector_provider_opts,
      },
      file_selector = {
        provider_opts = selector_provider_opts,
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
        position = "right",
        wrap = true,
      },
    }
  end,
  config = function(_, opts)
    require("fml.dressing.plugin").mock_miniicons()
    require("fml.dressing.plugin").mock_dressing()

    --- Hack: ensure the nerd fonts enabled.
    require("avante.utils").icons_enabled = function()
      return true
    end

    require("avante").setup(opts)
    std.fn.observe({ eve.context.flight.ai_provider }, function()
      local ai_provider = eve.context.flight.ai_provider:snapshot()
      local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot"
      vim.cmd("AvanteSwitchProvider " .. provider_name)
    end, true)
  end,
}
