---@see https://github.com/nvim-mini/mini.hipatterns/tree/add8d8abad602787377ec5d81f6b248605828e0f

---@type table<string, true>
local css_filetypes = {
  ["astro"] = true,
  ["css"] = true,
  ["html"] = true,
  ["javascriptreact"] = true,
  ["less"] = true,
  ["markdown"] = true,
  ["scss"] = true,
  ["svelte"] = true,
  ["typescriptreact"] = true,
  ["vue"] = true,
}

---@type table<string, true>
local md_filetypes = {
  ["acp-chatbox"] = true,
  ["acp-main"] = true,
  ["image-viewer"] = true,
  ["markdown"] = true,
  ["notepad"] = true,
}

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
  event = "VeryLazy",
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

        -- warn: WARNING, QUESTION, HELP, ATTENTION, HACK
        warn_keywords = {
          pattern = {
            "%f[%w]()HACK()%f[%W]",
            "%f[%w]()WARN()%f[%W]",
            "%f[%w]()WARNING()%f[%W]",
            "%f[%w]()QUESTION()%f[%W]",
            "%f[%w]()HELP()%f[%W]",
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
            local bufnr = vim.api.nvim_get_current_buf() ---@type integer
            local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
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
            local colors = stl.lang.tailwind.palette[color]
            local hex = colors and colors[shade] or nil ---@type string|nil
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

        rgb_color = {
          pattern = function()
            local bufnr = vim.api.nvim_get_current_buf() ---@type integer
            if css_filetypes[vim.api.nvim_get_option_value("filetype", { buf = bufnr })] then
              return "rgba?%(%d+,%s*%d+,%s*%d+[^%)]*%)"
            end
          end,
          group = function(_, _, data)
            local match = data.full_match
            local r, g, b = match:match("rgba?%((%d+),%s*(%d+),%s*(%d+)")
            if r and g and b then
              local hex = string.format("#%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
              return hipatterns.compute_hex_color_group(hex, "fg")
            end
          end,
          extmark_opts = function(_, _, data)
            return {
              priority = 2000,
              virt_text = { { "󱓻 ", data.hl_group } },
              virt_text_pos = "inline",
            }
          end,
        },

        hsl_color = {
          pattern = function()
            local bufnr = vim.api.nvim_get_current_buf() ---@type integer
            if css_filetypes[vim.api.nvim_get_option_value("filetype", { buf = bufnr })] then
              return "hsla?%(%d+,%s*%d+%%,%s*%d+%%[^%)]*%)"
            end
          end,
          group = function(_, _, data)
            local match = data.full_match
            local h, s, l = match:match("hsla?%((%d+),%s*(%d+)%%,%s*(%d+)%%")
            if h and s and l then
              h, s, l = tonumber(h) / 360, tonumber(s) / 100, tonumber(l) / 100
              local r, g, b
              if s == 0 then
                r, g, b = l, l, l
              else
                local function hue2rgb(p, q, t)
                  if t < 0 then
                    t = t + 1
                  end
                  if t > 1 then
                    t = t - 1
                  end
                  if t < 1 / 6 then
                    return p + (q - p) * 6 * t
                  end
                  if t < 1 / 2 then
                    return q
                  end
                  if t < 2 / 3 then
                    return p + (q - p) * (2 / 3 - t) * 6
                  end
                  return p
                end
                local q = l < 0.5 and l * (1 + s) or l + s - l * s
                local p = 2 * l - q
                r = hue2rgb(p, q, h + 1 / 3)
                g = hue2rgb(p, q, h)
                b = hue2rgb(p, q, h - 1 / 3)
              end
              local hex = string.format("#%02x%02x%02x", r * 255, g * 255, b * 255)
              return hipatterns.compute_hex_color_group(hex, "fg")
            end
          end,
          extmark_opts = function(_, _, data)
            return {
              priority = 2000,
              virt_text = { { "󱓻 ", data.hl_group } },
              virt_text_pos = "inline",
            }
          end,
        },

        -- Markdown titled separator: ---Title---
        md_titled_separator = {
          pattern = function()
            local bufnr = vim.api.nvim_get_current_buf() ---@type integer
            if md_filetypes[vim.api.nvim_get_option_value("filetype", { buf = bufnr })] then
              return "^%-%-%-()[^%-\n].+[^%-]()%-%-%-$"
            end
          end,
          group = "f_md_titled_separator",
        },
      },
    })
  end,
}
