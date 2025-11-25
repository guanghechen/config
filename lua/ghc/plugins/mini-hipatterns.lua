---@see https://github.com/nvim-mini/mini.hipatterns/tree/add8d8abad602787377ec5d81f6b248605828e0f

local tailwind = require("eve.constant.lang.tailwind")

---@type table<string, true>
local tailwind_filetypes = {
  ["astro"] = true,
  ["css"] = true,
  ["heex"] = true,
  ["html"] = true,
  ["html-eex"] = true,
  ["javascript"] = true,
  ["javascriptreact"] = true,
  ["rust"] = true,
  ["svelte"] = true,
  ["typescript"] = true,
  ["typescriptreact"] = true,
  ["vue"] = true,
}

return {
  name = "mini.hipatterns",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  ft = eve.filetype.get_hipattern_filetypes(),
  config = function()
    local hipatterns = require("mini.hipatterns")
    hipatterns.setup({
      highlighters = {
        hex_color = hipatterns.gen_highlighter.hex_color({
          inline_text = "󱓻 ",
          priority = 2000,
          style = "inline",
        }),

        -- error: FIXME, CAUTION, FAILURE, FAIL, MISSING, DANGER, ERROR, BUG
        error_keywords = {
          pattern = {
            "%f[%w]()FIXME()%f[%W]",
            "%f[%w]()CAUTION()%f[%W]",
            "%f[%w]()FAILURE()%f[%W]",
            "%f[%w]()FAIL()%f[%W]",
            "%f[%w]()MISSING()%f[%W]",
            "%f[%w]()DANGER()%f[%W]",
            "%f[%w]()ERROR()%f[%W]",
            "%f[%w]()BUG()%f[%W]",
          },
          group = "f_hipattern_error",
        },

        -- warn: WARNING, QUESTION, HELP, FAQ, ATTENTION, HACK
        warn_keywords = {
          pattern = {
            "%f[%w]()HACK()%f[%W]",
            "%f[%w]()WARNING()%f[%W]",
            "%f[%w]()QUESTION()%f[%W]",
            "%f[%w]()HELP()%f[%W]",
            "%f[%w]()FAQ()%f[%W]",
            "%f[%w]()ATTENTION()%f[%W]",
          },
          group = "f_hipattern_warn",
        },

        -- todo: TODO, WIP
        todo_keywords = {
          pattern = {
            "%f[%w]()TODO()%f[%W]",
            "%f[%w]()WIP()%f[%W]",
          },
          group = "f_hipattern_todo",
        },

        -- info: NOTE, ABSTRACT, SUMMARY, TLDR, INFO
        info_keywords = {
          pattern = {
            "%f[%w]()NOTE()%f[%W]",
            "%f[%w]()ABSTRACT()%f[%W]",
            "%f[%w]()SUMMARY()%f[%W]",
            "%f[%w]()TLDR()%f[%W]",
            "%f[%w]()INFO()%f[%W]",
          },
          group = "f_hipattern_info",
        },

        -- success: TIP, HINT, SUCCESS, CHECK, DONE
        success_keywords = {
          pattern = {
            "%f[%w]()TIP()%f[%W]",
            "%f[%w]()HINT()%f[%W]",
            "%f[%w]()SUCCESS()%f[%W]",
            "%f[%w]()CHECK()%f[%W]",
            "%f[%w]()DONE()%f[%W]",
          },
          group = "f_hipattern_success",
        },

        -- hint: IMPORTANT, EXAMPLE
        hint_keywords = {
          pattern = {
            "%f[%w]()IMPORTANT()%f[%W]",
            "%f[%w]()EXAMPLE()%f[%W]",
          },
          group = "f_hipattern_hint",
        },

        -- quote: QUOTE, CITE
        quote_keywords = {
          pattern = {
            "%f[%w]()QUOTE()%f[%W]",
            "%f[%w]()CITE()%f[%W]",
          },
          group = "f_hipattern_quote",
        },

        shorthand = {
          pattern = "#%x%x%x%f[^%x%w]",
          group = function(_, _, data)
            ---@type string
            local match = data.full_match
            local r, g, b = match:sub(2, 2), match:sub(3, 3), match:sub(4, 4)
            local hex_color = "#" .. r .. r .. g .. g .. b .. b
            return hipatterns.compute_hex_color_group(hex_color, "fg")
          end,
          extmark_opts = function(_, _, data)
            return {
              priority = 2000,
              right_gravity = false,
              virt_text = { { "󱓻 ", data.hl_group } },
              virt_text_pos = "inline",
            }
          end,
        },
        tailwind = {
          pattern = function()
            local filetype = vim.bo.filetype ---@type string
            if tailwind_filetypes[filetype] then
              return "%f[%w:-][%w:-]+%-[a-z%-]+%-%d+%f[^%w:-]"
            end
          end,
          group = function(_, _, m)
            local match = m.full_match ---@type string
            local color, shade = match:match("[%w-]+%-([a-z%-]+)%-(%d+)") ---@type string, number
            if color == nil or shade == nil then
              return
            end

            shade = tonumber(shade) or 0
            local hex = vim.tbl_get(tailwind.palette, color, shade)
            if hex then
              return hipatterns.compute_hex_color_group(hex, "fg")
            end
          end,
          extmark_opts = function(_, _, data)
            return {
              priority = 2000,
              right_gravity = false,
              virt_text = { { "󱓻 ", data.hl_group } },
              virt_text_pos = "inline",
            }
          end,
        },
      },
    })
  end,
}
