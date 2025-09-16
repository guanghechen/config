return {
  name = "blink.cmp",
  build = "cargo build --release",
  event = { "InsertEnter" },
  dependencies = {
    "friendly-snippets",
  },
  opts = function()
    local enabled_ai = eve.context.flight.ai:snapshot() ---@type boolean

    ---@class ghc.plugins.blink_cmp.actions
    local actions = {
      ---@return boolean|nil
      ai_accept = function()
        if enabled_ai then
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
    local sources_per_filetype = {
      [eve.filetype.UX_PICKER_FINDER] = { "path" },
    }
    do
      local code_sources = { "lsp", "path", "snippets", "buffer" }
      if enabled_ai then
        table.insert(code_sources, 1, "copilot") -- Insert at beginning for higher priority
      end
      -- Add our custom '@' path source
      table.insert(code_sources, "path_at")
      for _, cmp_code in ipairs(eve.filetype.list_code_filetypes()) do
        if sources_per_filetype[cmp_code] == nil then
          sources_per_filetype[cmp_code] = code_sources
        end
      end
    end

    return {
      enabled = function()
        if vim.bo.buftype == "nowrite" then
          return false
        end

        -- Disable on .env* files
        local bufname = vim.api.nvim_buf_get_name(0)
        local filename = vim.fn.fnamemodify(bufname, ":t")
        if filename:match("^%.env") or filename:match("%.http%.out$") then
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
        enabled = true,
        keymap = {
          ["<Tab>"] = { "show", "accept" },
        },
        completion = {
          menu = {
            auto_show = function()
              return vim.fn.getcmdtype() == ":"
            end,
          },
        },
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
              -- { "item_idx" },
              -- { "kind_icon", "source_name" },
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
            },
            components = {
              item_idx = {
                text = function(ctx)
                  return ctx.idx == 10 and "0" or ctx.idx >= 10 and " " or tostring(ctx.idx)
                end,
                highlight = "BlinkCmpItemIdx",
              },
              kind = {
                highlight = function(ctx)
                  return "BlinkCmpKind" .. ctx.kind
                end,
              },
              kind_icon = {
                text = function(ctx)
                  return eve.icon.kind[ctx.kind] .. " "
                end,
                highlight = function(ctx)
                  return "BlinkCmpKind" .. ctx.kind
                end,
              },
              label = {
                highlight = function()
                  return "BlinkCmpLabel"
                end,
              },
              source_name = {
                text = function(ctx)
                  return ctx.source_name:lower()
                end,
                highlight = function()
                  return "BlinkCmpSource"
                end,
              },
            },
          },
          direction_priority = function()
            local ctx = require("blink.cmp").get_context()
            local item = require("blink.cmp").get_selected_item()
            if ctx == nil or item == nil then
              return { "s", "n" }
            end

            local item_text = item.textEdit ~= nil and item.textEdit.newText or item.insertText or item.label
            local is_multiline = item_text:find("\n") ~= nil

            -- after showing the menu upwards, we want to maintain that direction
            -- until we re-open the menu, so store the context id in a global variable
            if is_multiline or vim.g.blink_cmp_upwards_ctx_id == ctx.id then
              vim.g.blink_cmp_upwards_ctx_id = ctx.id
              return { "n", "s" }
            end
            return { "s", "n" }
          end,
        },
      },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
        sorts = {
          "score",
          "exact",
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

      -- stylua: ignore start
      ['<C-1>'] = { function(cmp) cmp.accept({ index = 1 }) end },
      ['<C-2>'] = { function(cmp) cmp.accept({ index = 2 }) end },
      ['<C-3>'] = { function(cmp) cmp.accept({ index = 3 }) end },
      ['<C-4>'] = { function(cmp) cmp.accept({ index = 4 }) end },
      ['<C-5>'] = { function(cmp) cmp.accept({ index = 5 }) end },
      ['<C-6>'] = { function(cmp) cmp.accept({ index = 6 }) end },
      ['<C-7>'] = { function(cmp) cmp.accept({ index = 7 }) end },
      ['<C-8>'] = { function(cmp) cmp.accept({ index = 8 }) end },
      ['<C-9>'] = { function(cmp) cmp.accept({ index = 9 }) end },
      ['<C-0>'] = { function(cmp) cmp.accept({ index = 10 }) end },
        -- stylua: ignore end
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
          buffer = {
            name = "buffer",
            module = "blink.cmp.sources.buffer",
            score_offset = 100,
            opts = {
              get_bufnrs = function()
                local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
                local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
                if meta == nil then
                  return {}
                end

                local bufnrs = {} ---@type integer[]
                local max_buffers = 10 -- Limit to prevent resource exhaustion
                local count = 0

                for _, buf in ipairs(meta.bufs) do
                  if count >= max_buffers then
                    break
                  end

                  local bufnr = buf.bufnr ---@type integer
                  if vim.bo[bufnr].buftype == "" then
                    -- Only include buffers that are reasonably sized (< 1MB)
                    local bufname = vim.api.nvim_buf_get_name(bufnr)
                    if bufname ~= "" then
                      local size = vim.fn.getfsize(bufname)
                      if size >= 0 and size < 131072 then -- 128KB limit, -1 means file doesn't exist
                        bufnrs[#bufnrs + 1] = bufnr
                        count = count + 1
                      end
                    else
                      -- For unnamed buffers, include them (they're usually small)
                      bufnrs[#bufnrs + 1] = bufnr
                      count = count + 1
                    end
                  end
                end
                return bufnrs
              end,
            },
          },
          cmdline = {
            name = "cmdline",
            module = "blink.cmp.sources.cmdline",
          },
          copilot = enabled_ai and {
            name = "copilot",
            module = "ghc.cmp.copilot",
            score_offset = 300,
            async = true,
          } or nil,
          lsp = {
            name = "lsp",
            module = "blink.cmp.sources.lsp",
            score_offset = 180,
          },
          path = {
            name = "path",
            module = "blink.cmp.sources.path",
            score_offset = 200,
            opts = {
              ignore_root_slash = std.path.is_git_repo(),
              show_hidden_files_by_default = true,
            },
          },
          path_at = {
            name = "path_at",
            module = "ghc.cmp.path",
            score_offset = 210,
            opts = {
              show_hidden_files_by_default = true,
            },
          },
          snippets = {
            name = "snippets",
            module = "blink.cmp.sources.snippets",
            score_offset = 160,
          },
        },
      },
    }
  end,
}
