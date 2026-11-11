local ark_autocmd = require("__test__.support.ark_autocmd")
local harness = require("__test__.support.harness")

local t = harness.new()

---Registers the handler that keeps [[ and ]] after Neovim's filetype plugins, as the configuration's own handlers are,
---and returns a function that gives buffer `bufnr`, a new one by default, a filetype.
---@return fun(filetype: string, bufnr: integer|nil): integer
local function keep_reference_jumps()
  local create_augroup, create_autocmd = vim.api.nvim_create_augroup, vim.api.nvim_create_autocmd
  local handler = assert(ark_autocmd.load(t).ark_keep_reference_jumps, "the handler")
  vim.cmd("filetype plugin on")
  local group = create_augroup("keep_reference_jumps_spec", { clear = true })
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  create_autocmd("FileType", { group = group, callback = handler.callback })
  return function(filetype, bufnr)
    bufnr = bufnr or t:buffer(nil, { listed = true })
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    return bufnr
  end
end

---Global [[ and ]] in Normal and Visual mode, as the configuration maps them: with a Lua callback.
---@return nil
local function map_reference_jumps()
  for _, lhs in ipairs({ "[[", "]]" }) do
    vim.keymap.set({ "n", "x" }, lhs, function() end, { desc = "reference" })
    t:defer(function()
      vim.keymap.del({ "n", "x" }, lhs)
    end)
  end
end

---Who maps `lhs` in `mode` in buffer `bufnr` itself: the description of the map, "runtime" for a map of Neovim's
---filetype plugins without one, or nil.
---@param bufnr                         integer
---@param mode                          string
---@param lhs                           string
---@return string|nil
local function owner(bufnr, mode, lhs)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if keymap.lhs == lhs then
      return keymap.desc or (keymap.sid > 0 and "runtime" or "?")
    end
  end
end

t:test("Neovim's filetype plugins give [[ and ]] to the global maps in Normal and Visual mode", function()
  map_reference_jumps()
  local filetype = keep_reference_jumps()

  local python = filetype("python")
  t.assert_eq("reference", owner(python, "n", "[["), "python, Normal")
  t.assert_eq("reference", owner(python, "x", "]]"), "python, Visual")
  t.assert_eq("runtime", owner(python, "o", "]]"), "python, Operator-pending")
  -- One :noremap covers Normal, Visual and Operator-pending mode.
  local go = filetype("go")
  t.assert_eq("reference", owner(go, "n", "]]"), "go, Normal")
  t.assert_eq("reference", owner(go, "x", "[["), "go, Visual")
  t.assert_eq("runtime", owner(go, "o", "[["), "go, Operator-pending")
  t.assert_eq("reference", owner(filetype("markdown"), "n", "]]"), "markdown, mapped from Lua")

  local panel = t:buffer()
  vim.keymap.set("n", "[[", function() end, { buf = panel, desc = "page" })
  t.assert_eq("page", owner(filetype("diffview-commits", panel), "n", "[["), "a map of the configuration's own")
end)

t:test("a filetype plugin still undoes [[ and ]] after they give way to the global maps", function()
  map_reference_jumps()
  local filetype = keep_reference_jumps()

  -- Their undo unmaps [[ without `silent!`, which fails on a map that is gone.
  for _, name in ipairs({ "gdscript", "abaqus" }) do
    local bufnr = filetype(name)
    t.assert_eq("reference", owner(bufnr, "n", "[["), name)
    filetype("text", bufnr)
    t.assert_nil(owner(bufnr, "n", "[["), name .. " undone")
  end
end)

t:test("without global [[ and ]], filetype plugins keep their own", function()
  local filetype = keep_reference_jumps()

  local python = filetype("python")
  t.assert_eq("runtime", owner(python, "n", "[["))
  local rhs = vim.api.nvim_buf_call(python, function()
    return vim.fn.maparg("[[", "n")
  end)
  t.assert_true(rhs:find("Python_jump", 1, true) ~= nil, "the map as the ftplugin set it: " .. rhs)
end)

t:test("FileType for a buffer other than the current one gives way where the filetype plugin maps", function()
  map_reference_jumps()
  local filetype = keep_reference_jumps()
  local other = filetype("python")
  local current = vim.api.nvim_get_current_buf()

  -- Neovim's filetype plugins then map in the current buffer, as for notepad's call.
  vim.api.nvim_exec_autocmds("FileType", { buf = other })
  t.assert_eq("reference", owner(current, "n", "[["), "the current buffer")
  t.assert_eq("reference", owner(other, "n", "[["), "the event's buffer")
end)

t:run()
