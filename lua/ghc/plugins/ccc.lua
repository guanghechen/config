---@see https://github.com/uga-rosa/ccc.nvim/tree/9d1a256e006decc574789dfc7d628ca11644d4c2

return {
  name = "ccc.nvim",
  cmd = { "CccPick", "CccConvert" },
  config = function()
    local ccc = require("ccc")
    local input = ccc.input
    local output = ccc.output
    local picker = ccc.picker
    local mapping = ccc.mapping
    local utils = require("ccc.utils")

    ccc.setup({
      alpha_show = "show",
      auto_close = false,
      bar_char = "█",
      bar_len = 30,
      default_color = "#000000",
      disable_default_mappings = true,
      empty_point_bg = true,
      highlight_mode = "virtual",
      lsp = true,
      max_prev_colors = 10,
      point_char = "󰫢",
      point_color = "",
      point_color_on_dark = "#FFFFFF",
      point_color_on_light = "#000000",
      preserve = true,
      save_on_quit = true,
      virtual_pos = "inline-left",
      virtual_symbol = "󱓻 ",

      ----------------------------------------------------------------------------------------------

      highlighter = {
        auto_enable = false,
        max_byte = 100 * 1024,
        filetypes = {},
        excludes = {},
        lsp = true,
        picker = true,
        update_insert = true,
      },
      inputs = {
        input.rgb,
        input.hsl,
        input.hsv,
      },
      outputs = {
        output.hex,
        output.css_rgb,
        output.css_hsl,
      },
      pickers = {
        picker.hex,
        picker.hex_long,
        picker.css_rgb,
        picker.css_hsl,
      },
      win_opts = {
        relative = "cursor",
        row = 1,
        col = 1,
        style = "minimal",
        border = "rounded",
      },

      ----------------------------------------------------------------------------------------------

      mappings = {
        -- Confirm / Quit
        ["<CR>"] = mapping.complete,
        ["q"] = mapping.quit,

        -- Adjust value
        ["h"] = mapping.decrease1,
        ["l"] = mapping.increase1,
        ["s"] = mapping.decrease5,
        ["d"] = mapping.increase5,
        ["m"] = mapping.decrease10,
        [","] = mapping.increase10,

        -- Set percentage
        ["0"] = mapping.set0,
        ["1"] = utils.bind(mapping._set_percent, 10),
        ["2"] = utils.bind(mapping._set_percent, 20),
        ["3"] = utils.bind(mapping._set_percent, 30),
        ["4"] = utils.bind(mapping._set_percent, 40),
        ["5"] = mapping.set50,
        ["6"] = utils.bind(mapping._set_percent, 60),
        ["7"] = utils.bind(mapping._set_percent, 70),
        ["8"] = utils.bind(mapping._set_percent, 80),
        ["9"] = utils.bind(mapping._set_percent, 90),
        ["H"] = mapping.set0,
        ["M"] = mapping.set50,
        ["L"] = mapping.set100,

        -- Mode switch
        ["i"] = mapping.cycle_input_mode,
        ["o"] = mapping.cycle_output_mode,
        ["a"] = mapping.toggle_alpha,
        ["r"] = mapping.reset_mode,

        -- Previous colors
        ["g"] = mapping.toggle_prev_colors,
        ["b"] = mapping.goto_prev,
        ["w"] = mapping.goto_next,
        ["B"] = mapping.goto_head,
        ["W"] = mapping.goto_tail,

        -- Mouse
        ["<LeftMouse>"] = mapping.click,
        ["<ScrollWheelUp>"] = mapping.increase1,
        ["<ScrollWheelDown>"] = mapping.decrease1,
      },
    })
  end,
}
