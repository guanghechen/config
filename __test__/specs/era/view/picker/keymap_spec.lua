require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Keymap = require("era.view.picker.keymap")

---The descriptions of the buffer-local mappings of `bufnr` in `mode`, by their keys.
---@param bufnr                         integer
---@param mode                          string
---@return table<string, string>
local function described(bufnr, mode)
  local descs = {} ---@type table<string, string>
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    descs[vim.fn.keytrans(mapping.lhsraw)] = mapping.desc or mapping.rhs
  end
  return descs
end

t:test("a read-only pane binds its Normal keys in Insert mode too, and the Normal motions it leaves", function()
  local bufnr = t:buffer({ "1", "2", "3", "4", "5" }, { current = true })
  Keymap.bind({
    { modes = { "n", "x" }, key = "zx", desc = "case: normal", callback = stl.fn.noop },
    { modes = { "n" }, key = "j", desc = "case: own j", callback = stl.fn.noop },
    { modes = { "x" }, key = "zv", desc = "case: visual", callback = stl.fn.noop },
    { modes = { "i", "n" }, key = "zi", desc = "case: insert", callback = stl.fn.noop },
    { modes = { "n" }, key = "zs", desc = "case: key sequence", callback = "<C-d>" },
  }, bufnr)

  local insert = described(bufnr, "i")
  t.assert_eq("case: normal", insert.zx, "a Normal key")
  t.assert_eq("case: own j", insert.j, "a key of the pane takes over the motion")
  t.assert_eq("case: insert", insert.zi, "an Insert key")
  t.assert_nil(insert.zv, "a Visual-only key")
  t.assert_nil(insert.zs, "a key sequence, which means other keys in Insert mode")
  for lhs, key in pairs({ k = "k", gg = "gg", G = "G", ["<C-D>"] = "<C-d>", ["<C-U>"] = "<C-u>" }) do
    t.assert_eq("picker: Normal-mode " .. key, insert[lhs], "motion " .. key)
  end
  t.assert_eq("case: normal", described(bufnr, "x").zx, "the Normal key keeps its Visual mode")

  local motions = {} ---@type table<string, fun(): nil>
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "i")) do
    motions[mapping.lhs] = mapping.callback
  end
  motions.G()
  t.assert_eq(5, vim.api.nvim_win_get_cursor(0)[1], "G")
  motions.k()
  t.assert_eq(4, vim.api.nvim_win_get_cursor(0)[1], "k")
  motions.gg()
  t.assert_eq(1, vim.api.nvim_win_get_cursor(0)[1], "gg")
end)

t:test("a flag takes its toggle key, and a numbered one <C-number> in Insert mode too", function()
  local function flag(key)
    return { key = key, desc = "case: " .. key, callback = stl.fn.noop, snapshot = stl.fn.noop }
  end
  local keymaps = Keymap.flags({ flag("t5"), flag("ts") })
  local bound = {} ---@type table<string, string>
  for _, keymap in ipairs(keymaps) do
    bound[keymap.key] = table.concat(keymap.modes, ",")
  end
  t.assert_same({ ["<C-5>"] = "i,n,x", t5 = "n,x", ts = "n,x" }, bound)
end)

t:run()
