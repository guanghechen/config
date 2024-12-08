local icons = require("eve.lib.icons")
local util_cmp = require("guanghechen.util.cmp")

local cmp_sources_map = {
  basic = {
    { name = "path", group_index = 1, priority = 100 },
    { name = "buffer", group_index = 2, priority = 80 },
  },
  code = {
    { name = "copilot", group_index = 1, priority = 100 },
    { name = "path", group_index = 1, priority = 99 },
    { name = "nvim_lsp", group_index = 1, priority = 98 },
    { name = "snippets", group_index = 2, priority = 80 },
    { name = "buffer", group_index = 2, priority = 80 },
  },
}

return {
  name = "nvim-cmp",
  event = { "InsertEnter" },
  opts = function()
    local cmp = require("cmp") ---@type any
    local compare = require("cmp.config.compare")
    local options = {
      auto_brackets = {
        "python",
      }, -- configure any filetype to auto add brackets
      completion = {
        cmp = { enabled = true },
        completeopt = "menu,menuone,noinsert",
      },
      experimental = {
        ghost_text = {
          hl_group = "CmpGhostText",
        },
      },
      formatting = {
        -- default fields order i.e completion word + item.kind + item.kind icons
        fields = { "abbr", "kind", "menu" },
        format = function(_, item)
          local icon = icons.kind[item.kind] or icons.kind.Text ---@type string

          item.abbr = item.abbr .. " "
          item.menu_hl_group = "CmpItemKind" .. (item.kind or "")
          item.kind = icon .. " " .. (item.kind or "")

          local widths = { abbr = 40, menu = 30 }
          for key, width in pairs(widths) do
            if item[key] and vim.fn.strdisplaywidth(item[key]) > width then
              item[key] = vim.fn.strcharpart(item[key], 0, width - 1) .. "…"
            end
          end
          return item
        end,
      },
      mapping = {
        ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({
          behavior = cmp.ConfirmBehavior.Insert,
          select = true,
        }),
        ["<S-CR>"] = cmp.mapping.confirm({
          behavior = cmp.ConfirmBehavior.Replace,
          select = true,
        }),
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif vim.snippet.active({ direction = 1 }) then
            vim.schedule(function()
              vim.snippet.jump(1)
            end)
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif vim.snippet.active({ direction = -1 }) then
            vim.schedule(function()
              vim.snippet.jump(-1)
            end)
          else
            fallback()
          end
        end, { "i", "s" }),
      },
      preselect = cmp.PreselectMode.Item,
      snippet = {
        expand = function(args)
          util_cmp.expand(args.body)
        end,
      },
      sorting = {
        comparators = {
          compare.offset,
          compare.exact,
          compare.score,
          compare.recently_used,
          function(entry1, entry2)
            local _, entry1_under = entry1.completion_item.label:find("^_+")
            local _, entry2_under = entry2.completion_item.label:find("^_+")
            entry1_under = entry1_under or 0
            entry2_under = entry2_under or 0
            if entry1_under > entry2_under then
              return false
            elseif entry1_under < entry2_under then
              return true
            end
          end,
          compare.kind,
          compare.sort_text,
          compare.length,
          compare.order,
        },
      },
      sources = vim.list_slice(cmp_sources_map.basic),
      window = {
        completion = {
          scrollbar = false,
          side_padding = 1,
          border = "single",
          winhighlight = "Normal:CmpPmenu,CursorLine:CmpSel,Search:None,FloatBorder:CmpBorder",
        },
        documentation = {
          border = "single",
          winhighlight = "Normal:CmpDoc,FloatBorder:CmpDocBorder",
        },
      },
    }

    return options
  end,
  config = function(_, opts)
    local parse = require("cmp.utils.snippet").parse
    require("cmp.utils.snippet").parse = function(input)
      local ok, ret = pcall(parse, input)
      if ok then
        return ret
      end
      return util_cmp.snippet_preview(input)
    end

    local cmp = require("cmp") ---@type any
    cmp.event:on("confirm_done", function(event)
      if vim.tbl_contains(opts.auto_brackets or {}, vim.bo.filetype) then
        util_cmp.auto_brackets(event.entry)
      end
    end)
    cmp.event:on("menu_opened", function(event)
      util_cmp.add_missing_snippet_docs(event.window)
    end)

    cmp.setup(opts)
    cmp.setup.filetype(eve.filetype.get_cmp_code_filetypes(), {
      sources = vim.list_slice(cmp_sources_map.code),
    })
  end,
  dependencies = {
    "cmp-buffer",
    "cmp-nvim-lsp",
    "cmp-path",
    "copilot-cmp",
    "nvim-snippets",
  },
}
