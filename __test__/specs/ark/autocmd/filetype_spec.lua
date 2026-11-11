local ark_autocmd = require("__test__.support.ark_autocmd")
local fs = require("__test__.support.fs")
local harness = require("__test__.support.harness")

local t = harness.new()

-- Patterns of equal priority are tried in an order that changes from one process to the next, so each overlap below
-- passed or failed by chance before the configuration stopped competing with Neovim's own patterns.
t:test("filetype patterns match the intended files and leave Neovim's own rules in place", function()
  ark_autocmd.load(t)

  for filepath, expected in pairs({
    ["/home/user/.config/fzf/fzf.fzfrc"] = "bash",
    ["/home/user/.config/ripgrep/web.tsx.ripgreprc"] = "bash",
    ["/home/user/.config/tmux/conf/keymap.tmux.conf"] = "tmux",
    ["/repo/.vscode/settings.json"] = "jsonc",
    ["/repo/data.json5"] = "json5",
    ["/home/user/.vimrc"] = "vim",
    ["/repo/resource.rc"] = "rc",
    ["/repo/.env"] = "env",
    ["/repo/.env.local"] = "env",
    ["/repo/.env.production"] = "env",
    ["/home/user/.config/kitty/kitty.conf"] = "kitty",
    ["/home/user/.config/kitty/theme.conf"] = "kitty",
    ["/home/user/.config/kitty/current-theme.conf"] = "kitty",
  }) do
    t.assert_eq(expected, (vim.filetype.match({ filename = filepath })), filepath)
  end
end)

t:test("a file over the size limit is a bigfile even where Neovim has a pattern for its path", function()
  ark_autocmd.load(t)
  t:patch_table(vim.g, "bigfile_size", 8)
  local dir = t:tempdir()

  for _, name in ipairs({ "hypr/big.conf", "kitty/big.conf", "lxqt/big.conf", "project/.env.big" }) do
    local filepath = vim.fs.joinpath(dir, name)
    fs.write(filepath, { "longer than the size limit" })
    local bufnr = vim.fn.bufadd(filepath) ---@type integer
    t:defer(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    t.assert_eq("bigfile", (vim.filetype.match({ filename = filepath, buf = bufnr })), name)
  end
end)

t:run()
