local ark_autocmd = require("__test__.support.ark_autocmd")
local harness = require("__test__.support.harness")

local t = harness.new()

t:test("refreshes the filepath cache after a buffer rename", function()
  local _, events = ark_autocmd.load(t)

  t.assert_same({ "BufWinEnter", "BufFilePost" }, events.ark_cache_buf_filepath, "cache refresh events")
end)

t:test("q stays free for recording macros in a commit message", function()
  local autocmds = ark_autocmd.load(t)

  t.assert_false(vim.tbl_contains(autocmds.ark_close_filetypes_with_q.pattern, "gitcommit"))
end)

for _, host in ipairs({ "neovim", "neovide", "vscode", "yozvim", "yuivim" }) do
  t:test(host .. " keeps Python environment setup under the correct owner", function()
    t:patch_table(vim, "g", host == "neovim" and {} or { [host] = true })
    local autocmds = ark_autocmd.load(t)
    local expected = host == "neovim" or host == "neovide"
    t.assert_eq(expected, autocmds.ark_python_venv ~= nil, "Python FileType handler")
  end)
end

t:run()
