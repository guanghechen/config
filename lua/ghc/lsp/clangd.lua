local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = eve.lsp.on_attach,
  on_init = eve.lsp.on_init,
  settings = {
    clangd = {
      cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=iwyu",
        "--completion-style=detailed",
        "--function-arg-placeholders",
        "--fallback-style=llvm",
      },
      filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
      keys = {
        { "<leader>cR", "<cmd>ClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
      },
      root_dir = function(fname)
        return require("lspconfig.util").root_pattern(
          "Makefile",
          "configure.ac",
          "configure.in",
          "config.h.in",
          "meson.build",
          "meson_options.txt",
          "build.ninja"
        )(fname) or require("lspconfig.util").root_pattern("compile_commands.json", "compile_flags.txt")(fname) or require(
          "lspconfig.util"
        ).find_git_ancestor(fname)
      end,
      capabilities = {
        offsetEncoding = { "utf-16" },
      },
      init_options = {
        usePlaceholders = true,
        completeUnimported = true,
        clangdFileStatus = true,
      },
    },
  },
}
