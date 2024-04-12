return {
  -- Use Eslint for fix on save and prettier for formatting
  -- https://www.lazyvim.org/configuration/recipes#use-eslint-for-fix-on-save-and-prettier-for-formatting
  { import = "lazyvim.plugins.extras.linting.eslint" },
  { import = "lazyvim.plugins.extras.formatting.prettier" },

  -- Add extra langauges support.
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.json" },
}
