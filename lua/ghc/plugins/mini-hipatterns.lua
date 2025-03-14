local ft = require("eve.constant.filetype")
local tailwind = require("eve.constant.lang.tailwind")

---@type table<string,true>
local highlighted = {}

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
  ft = ft.get_hipattern_filetypes(),
  config = function()
    local hipatterns = require("mini.hipatterns")
    hipatterns.setup({
      highlighters = {
        hex_color = hipatterns.gen_highlighter.hex_color({ priority = 2000 }),
        -- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
        fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
        hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
        todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
        note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
        shorthand = {
          pattern = "()#%x%x%x()%f[^%x%w]",
          group = function(_, _, data)
            ---@type string
            local match = data.full_match
            local r, g, b = match:sub(2, 2), match:sub(3, 3), match:sub(4, 4)
            local hex_color = "#" .. r .. r .. g .. g .. b .. b
            return hipatterns.compute_hex_color_group(hex_color, "bg")
          end,
          extmark_opts = { priority = 2000 },
        },
        tailwind = {
          extmark_opts = { priority = 2000 },
          pattern = function()
            local filetype = vim.bo.filetype ---@type string
            if tailwind_filetypes[filetype] then
              return "%f[%w:-]()[%w:-]+%-[a-z%-]+%-%d+()%f[^%w:-]"
            end
          end,
          group = function(_, _, m)
            local match = m.full_match ---@type string
            local color, shade = match:match("[%w-]+%-([a-z%-]+)%-(%d+)") ---@type string, number
            if color == nil or shade == nil then
              return
            end

            local hl = "f_tailwind_" .. color .. shade ---@type string
            if highlighted[hl] then
              return hl
            end

            shade = tonumber(shade) or 0
            local bg = vim.tbl_get(tailwind.palette, color, shade)
            if bg then
              highlighted[hl] = true
              local fg_shade = shade == 500 and 950 or shade < 500 and 900 or 100
              local fg = vim.tbl_get(tailwind.palette, color, fg_shade)
              vim.api.nvim_set_hl(0, hl, { fg = fg, bg = bg })
              return hl
            end
          end,
        },
      },
    })

    -- reset hl groups when colorscheme changes
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = eve.nvim.augroup("mini-hipatterns_reset_colorscheme"),
      callback = function()
        highlighted = {}
      end,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = eve.nvim.augroup("mini-hipatterns_auto_enable"),
      pattern = { ft.AVANTE, ft.AVANTE_INPUT },
      callback = function(arg)
        require("mini.hipatterns").enable(arg.buf)
      end,
    })
  end,
}
