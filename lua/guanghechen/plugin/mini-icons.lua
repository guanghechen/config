return {
  "echasnovski/mini.icons",
  lazy = true,
  opts = {
    file = {
      [".chezmoiignore"] = { glyph = "", hl = "MiniIconsGrey" },
      [".chezmoiremove"] = { glyph = "", hl = "MiniIconsGrey" },
      [".chezmoiroot"] = { glyph = "", hl = "MiniIconsGrey" },
      [".chezmoiversion"] = { glyph = "", hl = "MiniIconsGrey" },
      [".eslintignore"] = { glyph = "󰱺", hl = "MiniIconsPurple" },
      [".eslintrc"] = { glyph = "󰱺", hl = "MiniIconsPurple" },
      [".eslintrc.js"] = { glyph = "󰱺", hl = "MiniIconsPurple" },
      [".eslintrc.json"] = { glyph = "󰱺", hl = "MiniIconsPurple" },
      [".go-version"] = { glyph = "", hl = "MiniIconsBlue" },
      [".keep"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
      [".node-version"] = { glyph = "", hl = "MiniIconsGreen" },
      [".prettierrc"] = { glyph = "", hl = "MiniIconsPurple" },
      [".prettierrc.js"] = { glyph = "", hl = "MiniIconsPurple" },
      [".yarnrc.yml"] = { glyph = "", hl = "MiniIconsBlue" },
      ["bash.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
      ["devcontainer.json"] = { glyph = "", hl = "MiniIconsBlue" },
      ["eslint.config.js"] = { glyph = "󰱺", hl = "MiniIconsYellow" },
      ["json.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
      ["package.json"] = { glyph = "", hl = "MiniIconsGreen" },
      ["ps1.tmpl"] = { glyph = "󰨊", hl = "MiniIconsGrey" },
      ["README"] = { glyph = "󰍔", hl = "MiniIconsGrey" },
      ["README.md"] = { glyph = "󰍔", hl = "MiniIconsGrey" },
      ["README.txt"] = { glyph = "󰍔", hl = "MiniIconsGrey" },
      ["sh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
      ["tailwind.config.js"] = { glyph = "󱏿", hl = "MiniIconsBlue" },
      ["tailwind.config.mjs"] = { glyph = "󱏿", hl = "MiniIconsBlue" },
      ["tailwind.config.ts"] = { glyph = "󱏿", hl = "MiniIconsBlue" },
      ["toml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
      ["tsconfig.json"] = { glyph = "", hl = "MiniIconsBlue" },
      ["tsconfig.build.json"] = { glyph = "", hl = "MiniIconsBlue" },
      ["yaml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
      ["yarn.lock"] = { glyph = "", hl = "MiniIconsBlue" },
      ["zsh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
    },
    filetype = {
      css = { glyph = "", hl = "MiniIconsBlue" },
      html = { glyph = "", hl = "MiniIconsRed" },
      dotenv = { glyph = "", hl = "MiniIconsYellow" },
      gitignore = { glyph = "󰊢", hl = "MiniIconsRed" },
      gotmpl = { glyph = "󰟓", hl = "MiniIconsGrey" },
    },
  },
  init = function()
    package.preload["nvim-web-devicons"] = function()
      require("mini.icons").mock_nvim_web_devicons()
      return package.loaded["nvim-web-devicons"]
    end
  end,
}
