return {
  name = "img-clip.nvim",
  keys = {
    { "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
  },
  opts = {
    default = {
      dir_path = "asset",
      embed_image_as_base64 = false,
      file_name = "%Y-%m-%d-%H-%M-%S",

      prompt_for_file_name = false,
      drag_and_drop = {
        insert_mode = true,
      },
      use_absolute_path = true,
    },
  },
}
