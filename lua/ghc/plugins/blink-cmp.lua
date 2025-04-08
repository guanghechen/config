---@class ghc.plugins.blink_cmp.actions
local actions = {
  ---@return boolean|nil
  ai_accept = function()
    local enabled = eve.state.flight.ai:snapshot() ---@type boolean
    if enabled and package.loaded["copilot"] then
      if require("copilot.suggestion").is_visible() then
        eve.nvim.create_undo()
        require("copilot.suggestion").accept()
        return true
      end
    end
  end,
  ---@return boolean|nil
  tab_fallback = function()
    local mode = vim.api.nvim_get_mode().mode ---@type string
    if mode == "i" then
      vim.fn.feedkeys("\t", "n")
      return true
    end
  end,
}

---@type table<string, string[]>
local sources_per_filetype = {}
for _, cmp_code in ipairs(eve.filetype.get_cmp_code_filetypes()) do
  sources_per_filetype[cmp_code] = { "copilot", "lsp", "path", "snippets", "buffer" }
end
for _, cmp_search in ipairs(eve.filetype.get_cmp_search_filetypes()) do
  sources_per_filetype[cmp_search] = { "path", "buffer" }
end

return {
  name = "blink.cmp",
  build = "cargo build --release",
  event = { "InsertEnter" },
  dependencies = {
    "friendly-snippets",
  },
  opts = {
    enabled = function()
      if vim.bo.buftype == "nowrite" then
        return false
      end

      local filetype = vim.bo.filetype ---@type string
      if not eve.filetype.is_cmp_enabled(filetype) then
        return false
      end

      return true
    end,
    appearance = {
      use_nvim_cmp_as_default = false,
      nerd_font_variant = "mono",
      kind_icons = eve.icon.kind,
    },
    cmdline = {
      enabled = false,
    },
    completion = {
      accept = {
        auto_brackets = {
          enabled = true,
        },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = {
          border = "rounded",
        },
      },
      ghost_text = {
        enabled = true,
      },
      list = {
        selection = {
          preselect = function()
            return not require("blink.cmp").snippet_active({ direction = 1 })
          end,
          auto_insert = true,
        },
      },
      keyword = {
        range = "prefix",
      },
      menu = {
        border = "rounded",
        draw = {
          treesitter = { "lsp" },
          columns = {
            { "kind_icon", "label", "label_description", gap = 1 },
            { "kind" },
          },
          components = {
            kind_icon = {
              text = function(ctx)
                return eve.icon.kind[ctx.kind] .. " "
              end,
              highlight = function(ctx)
                return "BlinkCmpKind" .. ctx.kind
              end,
            },
            kind = {
              highlight = function(ctx)
                return "BlinkCmpKind" .. ctx.kind
              end,
            },
          },
        },
      },
    },
    fuzzy = {
      implementation = "rust",
      sorts = {
        "exact",
        -- "defaults",
        "score",
        "sort_text",
      },
    },
    keymap = {
      preset = "none",
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = { "select_next", "snippet_forward", actions.ai_accept, actions.tab_fallback, "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", actions.ai_accept, actions.tab_fallback, "fallback" },

      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback_to_mappings" },
      ["<C-j>"] = { "select_next", "fallback_to_mappings" },
      ["<C-h>"] = { "hide" },
      ["<C-l>"] = { "select_and_accept" },

      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-p>"] = { "show_signature", "hide_signature", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "fallback" },
      ["<C-f>"] = { "scroll_documentation_down", "fallback" },
    },
    signature = {
      enabled = true,
      window = {
        border = "rounded",
        winblend = 50,
        show_documentation = false,
      },
    },
    snippets = {
      preset = "default",
    },
    sources = {
      default = {},
      per_filetype = sources_per_filetype,
      providers = {
        copilot = {
          name = "copilot",
          module = "ghc.cmp.copilot",
          score_offset = 100,
          async = true,
        },
      },
    },
  },
}
