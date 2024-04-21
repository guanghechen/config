local path = require("ghc.core.util.path")

local function set_term_ft(id)
  local term = nil
  for _, item in pairs(vim.g.nvchad_terms) do
    if item.id == id then
      term = item
      break
    end
  end

  if term ~= nil then
    vim.bo[term.buf].filetype = "nvchad-term"
  end
end

local terminal = {
  workspace = function()
    local id = "windows-terminal"
    require("nvchad.term").toggle({
      id = id,
      cmd = "cd " .. '"' .. path.workspace() .. '"',
      pos = "float",
    })
    set_term_ft(id)
  end,
  cwd = function()
    local id = "cwd-terminal"
    require("nvchad.term").toggle({
      id = id,
      cmd = "cd " .. '"' .. path.cwd() .. '"',
      pos = "float",
    })
    set_term_ft(id)
  end,
  current = function()
    local id = "current-terminal"
    require("nvchad.term").create({
      id = id,
      cmd = "cd " .. '"' .. path.current() .. '"',
      pos = "float",
    })
    set_term_ft(id)
  end,
}

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { noremap = true, silent = true, desc = "terminal: Exit terminal mode" })
vim.keymap.set("n", "<leader>tT", terminal.workspace, { noremap = true, silent = true, desc = "terminal: toggle terminal (workspace)" })
vim.keymap.set("n", "<leader>tt", terminal.cwd, { noremap = true, silent = true, desc = "terminal: toggle terminal (cwd)" })
