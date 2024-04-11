return {
  {
    "telescope.nvim",
    dependencies = {
      {
        -- Add telescope-fzf-native
        --  https://www.lazyvim.org/configuration/recipes#add-telescope-fzf-native
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        config = function()
          require("telescope").load_extension("fzf")
        end,
      },
    },
  },
}
