local env = require("eve.builtin.env")
local fn = require("eve.builtin.fn")
local Subscriber = require("eve.collection.subscriber")
local calc_fileicon = require("eve.module.fileicon").calc_fileicon
local state = require("eve.state")
local Select = require("fml.ux.select")

local AI_PROVIDER_MAP = {
  aoai = "azure",
  copilot = "copilot",
  deepseek = "deepseek",
}

local function setup_file_selector()
  local context = state.select.select_avante
  local _on_choice = fn.noop ---@type fun(items: fml.ux.select.IItem[] | nil): nil
  local _filepaths = {} ---@type string[]
  local _winnr = nil ---@type integer|nil
  local _confirmed = false ---@type boolean

  local _selector ---@type fml.ux.Select
  _selector = Select.new({
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
    frecency = state.frecency.files,
    input = context.input,
    input_history = context.input_history,
    multiple = true,
    preview_enabled = false,
    extend_preset_keymaps = true,
    permanent = true,
    provider = {
      fetch_data = function()
        local width = 0 ---@type integer
        local items = {} ---@type fml.ux.select.IItem[]
        for index, filepath in ipairs(_filepaths) do
          local uuid = tostring(index) ---@type string
          local text = filepath ---@type string
          local icon, icon_hl = calc_fileicon(filepath)
          local data = { filepath = filepath, icon = icon, icon_hl = icon_hl }
          local select_item = { uuid = uuid, text = text, data = data } ---@type fml.ux.select.IItem
          width = width < #text and #text or width ---@type integer
          items[#items + 1] = select_item
        end

        vim.schedule(function()
          _selector:change_dimension({
            height = #items + 3,
            max_height = math.min(math.floor(vim.o.lines * 0.8), 40),
            max_width = 0.8,
            width = math.max(60, width + 10),
          })
        end)
        return { items = items }
      end,
      render_item = function(item, match)
        local icon_width = string.len(item.data.icon) ---@type integer
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
    title = " (Avante) Add a file ",
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

  local FileSelector = require("avante.file_selector")
  function FileSelector:native_ui(handler)
    _filepaths = self:get_filepaths() ---@type string[]
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

    _selector:mark_data_dirty()
    _selector:show()
  end
end

return {
  "avante.nvim",
  build = env.IS_WIN and "pwsh -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" or "make",
  cmd = {
    "AvanteAsk",
    "AvanteBuild",
    "AvanteChat",
    "AvanteClear",
    "AvanteEdit",
    "AvanteFocus",
    "AvanteRefresh",
    "AvanteSwitchProvider",
    "AvanteToggle",
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
    local ai_provider = state.flight.ai_provider:snapshot() ---@type eve.e.AiProvider
    local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot" ---@type string
    return {
      azure = {
        endpoint = vim.env.AZURE_OPENAI_ENDPOINT,
        deployment = "gpt-4o",
        model = "gpt-4o",
        api_version = "2024-08-01-preview",
      },
      vendors = {
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          model = "deepseek-coder",
        },
      },

      provider = provider_name,
      auto_suggestions_provider = "copilot",

      ------------------------------------------------------------------------------------------------

      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",

        sidebar = {
          close = { "q" },
        },
        submit = {
          normal = "<CR>",
          -- insert = { "<C-s>", "<M-s>", "<C-a>s" },
          insert = "<C-s>",
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
      },
    }
  end,
  config = function(_, opts)
    package.loaded["dressing.nvim"] = {}

    require("avante").setup(opts)
    state.flight.ai_provider:subscribe(
      Subscriber.new({
        on_next = function(ai_provider)
          local provider_name = AI_PROVIDER_MAP[ai_provider] or "copilot"
          vim.cmd("AvanteSwitchProvider " .. provider_name)
        end,
      }),
      true
    )

    setup_file_selector()
  end,
}
