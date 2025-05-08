require("plenary.reload").reload_module("eve.ux.view.picker")

local picker = eve.ux.Picker.new({
  name = "file-picker",
  finder_title = "File Picker",
  finder_input = "eve/ux",
  finder_multiline = false,
  result_render = function(self, input)
    local bufnr = self:get_finder_bufnr() ---@type integer|nil
    if bufnr == nil then
      return 0
    end

    ---@type string[]
    local lines = {
      "Hello",
      ",",
      "World",
      "!",
      string.rep("----", 25),
      input,
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    return 2
  end,
})

picker:focus()
