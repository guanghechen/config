---  https://github.com/LazyVim/LazyVim/blob/0f6ff53ce336082869314db11e9dfa487cf83292/lua/lazyvim/util/cmp.lua#L1
local __module_name__ = "ghc.plugins.nvim-cmp" ---@type string

local cmp_sources_map = {
  basic = {
    { name = "path", group_index = 1, priority = 100 },
    -- { name = "buffer", group_index = 2, priority = 80 },
  },
  cmdline = {
    { name = "path", group_index = 1, priority = 100 },
  },
  code = {
    { name = "copilot", group_index = 1, priority = 100 },
    { name = "path", group_index = 1, priority = 99 },
    { name = "nvim_lsp", group_index = 1, priority = 98 },
    { name = "snippets", group_index = 2, priority = 80 },
    { name = "buffer", group_index = 2, priority = 80 },
  },
  search = {
    { name = "path", group_index = 1, priority = 100 },
  },
}

local actions = {
  -- This is a better implementation of `cmp.confirm`:
  --  * check if the completion menu is visible without waiting for running sources
  --  * create an undo point before confirming
  -- This function is both faster and more reliable.
  ---@param opts? {select: boolean, behavior: unknown}
  confirm = function(opts)
    local cmp = require("cmp")
    opts = vim.tbl_extend("force", {
      select = true,
      behavior = cmp.ConfirmBehavior.Insert,
    }, opts or {})
    return function(fallback)
      if cmp.core.view:visible() or vim.fn.pumvisible() == 1 then
        if vim.api.nvim_get_mode().mode == "i" then
          vim.api.nvim_feedkeys(eve.setting.feedkeys.UNDO, "n", false)
        end
        if cmp.confirm(opts) then
          return
        end
      end
      return fallback()
    end
  end,
}

---@class Placeholder
---@field public n string
---@field public text string

---@param snippet                       string
---@param callback                      fun(placeholder: Placeholder):string
---@return string
local function snippet_replace(snippet, callback)
  return snippet:gsub("%$%b{}", function(m)
    local n, name = m:match("^%${(%d+):(.+)}$")
    return n and callback({ n = n, text = name }) or m
  end) or snippet
end

-- This function resolves nested placeholders in a snippet.
---@param snippet string
---@return string
local function snippet_preview(snippet)
  local ret = snippet_replace(snippet, function(placeholder)
    return snippet_preview(placeholder.text)
  end):gsub("%$0", "")
  return ret
end

-- This function replaces nested placeholders in a snippet with LSP placeholders.
local function snippet_fix(snippet)
  return snippet_replace(snippet, function(placeholder)
    return "${" .. placeholder.n .. ":" .. snippet_preview(placeholder.text) .. "}"
  end)
end

-- This function adds missing documentation to snippets.
-- The documentation is a preview of the snippet.
local function snippet_add_missing_docs(window)
  local cmp = require("cmp")
  local Kind = cmp.lsp.CompletionItemKind
  local entries = window:get_entries()
  for _, entry in ipairs(entries) do
    if entry:get_kind() == Kind.Snippet then
      local item = entry:get_completion_item()
      if not item.documentation and item.insertText then
        item.documentation = {
          kind = cmp.lsp.MarkupKind.Markdown,
          value = string.format("```%s\n%s\n```", vim.bo.filetype, snippet_preview(item.insertText)),
        }
      end
    end
  end
end

---@param snippet                       string
---@return nil
local function snippet_expand(snippet)
  local ok = pcall(vim.snippet.expand, snippet)
  if not ok then
    local fixed = snippet_fix(snippet)
    ok = pcall(vim.snippet.expand, fixed)

    local msg = ok and "Failed to parse snippet,\nbut was able to fix it automatically." or "Failed to parse snippet."
    local formatted_msg = ([[%s
```%s
%s
```]]):format(msg, vim.bo.filetype, snippet)

    local log = ok and eve.reporter.warn or eve.reporter.error
    log({
      from = __module_name__,
      subject = "expand",
      message = formatted_msg,
    })
  end
end

local function auto_brackets(entry)
  local cmp = require("cmp")
  local Kind = cmp.lsp.CompletionItemKind
  local item = entry:get_completion_item()
  if item.kind == Kind.Function or item.kind == Kind.Method then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local prev_char = vim.api.nvim_buf_get_text(0, cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2] + 1, {})[1]
    if prev_char ~= "(" and prev_char ~= ")" then
      local keys = vim.api.nvim_replace_termcodes("()<left>", false, false, true)
      vim.api.nvim_feedkeys(keys, "i", true)
    end
  end
end

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
        completeopt = "menuone,noselect,popup",
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
          local icon = eve.icon.kind[item.kind] or eve.icon.kind.Text ---@type string

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
        ["<cr>"] = actions.confirm({
          behavior = cmp.ConfirmBehavior.Insert,
          select = true,
        }),
        ["<S-cr>"] = actions.confirm({
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
          snippet_expand(args.body)
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
        completion = cmp.config.window.bordered({
          side_padding = 0,
          border = "rounded",
          winhighlight = "Normal:CmpNormal,FloatBorder:CmpBorder,CursorLine:PmenuSel,Search:None",
        }),
        documentation = cmp.config.window.bordered({
          border = "rounded",
          winhighlight = "Normal:CmpDocNormal,FloatBorder:CmpDocBorder,CursorLine:PmenuSel,Search:None",
        }),
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
      return snippet_preview(input)
    end

    local cmp = require("cmp") ---@type any
    cmp.event:on("confirm_done", function(event)
      if opts.auto_brackets ~= nil and vim.list_contains(opts.auto_brackets, vim.bo.filetype) then
        auto_brackets(event.entry)
      end
    end)
    cmp.event:on("menu_opened", function(event)
      snippet_add_missing_docs(event.window)
    end)

    cmp.setup(opts)
    cmp.setup.cmdline("/", {
      sources = vim.list_slice(cmp_sources_map.cmdline),
    })
    cmp.setup.filetype(eve.filetype.get_cmp_code_filetypes(), {
      sources = vim.list_slice(cmp_sources_map.code),
    })
    cmp.setup.filetype(eve.filetype.get_cmp_search_filetypes(), {
      sources = vim.list_slice(cmp_sources_map.search),
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
