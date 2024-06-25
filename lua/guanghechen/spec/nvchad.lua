return {
  {
    "NvChad/ui",
    branch = "v2.5",
    lazy = false,
    config = function()
      require("nvchad")
    end,
  },
  {
    "NvChad/base46",
    branch = "v2.5",
    build = function()
      require("base46").load_all_highlights()
    end,
  },
}
