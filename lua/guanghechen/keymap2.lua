---@param mode                          string | string[]
---@param key                           string
---@param uuid                          string
local function mk(mode, key, uuid)
  local command = eve.commander.resolve(uuid, true)
  local desc = command ~= nil and command.desc or nil ---@type string|nil
  vim.keymap.set(mode, key, function()
    eve.commander.execute(uuid)
  end, { noremap = true, silent = true, nowait = true, desc = desc })
end

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>fb", eve.commander.uuids.find_buffers)
mk({ "n", "v" }, "<leader>fe", eve.commander.uuids.find_explorer)
mk({ "n", "v" }, "<leader>fh", eve.commander.uuids.find_highlights)
mk({ "n", "v" }, "<leader>fv", eve.commander.uuids.find_vim_options)
-------------------------------------------------------------------------------------------#[f]ind--

--#[s]elect-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>st", eve.commander.uuids.select_theme)
-----------------------------------------------------------------------------------------#[s]elect--
