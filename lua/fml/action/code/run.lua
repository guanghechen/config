local __module_name__ = "fml.action.code.run" ---@type string

---@class fml.action.code.IRunner
---@field public run                    fun(filepath: string, force: boolean): nil

---@class fml.action.code.IRunners
---@field public eventstream            fml.action.code.IRunner
---@field public excalidraw             fml.action.code.IRunner
---@field public html                   fml.action.code.IRunner
---@field public json                   fml.action.code.IRunner
---@field public jsonl                  fml.action.code.IRunner
---@field public log                    fml.action.code.IRunner
---@field public md                     fml.action.code.IRunner
---@field public svg                    fml.action.code.IRunner
---@field public txt                    fml.action.code.IRunner
---
---@field public lua                    fml.action.code.IRunner
---@field public mjs                    fml.action.code.IRunner

local YOZ_SERVER_PORT = type(vim.env.YOZ_SERVER_PORT) == "string" and vim.env.YOZ_SERVER_PORT or "7071" ---@type string

---@param filepath                      string
---@param force                         boolean
local function open_filepath_within_yoz(filepath, force)
  local url = string.format(
    "http://localhost:%s/api/file-switch?filepath=%s&force=%s",
    YOZ_SERVER_PORT,
    std.string.escape_url_component(filepath),
    force and "true" or "false"
  )
  vim.system({ "curl", "-X", "POST", url }, { detach = true })
end

---@type fml.action.code.IRunners
local runners = {
  eventstream = {
    run = open_filepath_within_yoz,
  },
  excalidraw = {
    run = open_filepath_within_yoz,
  },
  html = {
    run = open_filepath_within_yoz,
  },
  json = {
    run = open_filepath_within_yoz,
  },
  jsonl = {
    run = open_filepath_within_yoz,
  },
  log = {
    run = open_filepath_within_yoz,
  },
  md = {
    run = open_filepath_within_yoz,
  },
  svg = {
    run = open_filepath_within_yoz,
  },
  txt = {
    run = open_filepath_within_yoz,
  },

  --------------------------------------------------------------------------------------------------

  lua = {
    run = function(filepath)
      vim.cmd("luafile " .. filepath)
    end,
  },
  mjs = {
    run = function(filepath)
      ---@param termmeta                eve.builtin.term.IMeta
      ---@return nil
      local function handle(termmeta)
        local bufnr = termmeta.bufnr ---@type integer|nil
        if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
          local channel_id = vim.bo[bufnr].channel ---@type integer
          local cmd = "node " .. vim.fn.shellescape(filepath) .. "\n" ---@type string
          vim.fn.chansend(channel_id, cmd)
        end
      end

      local termuuid = "9b2efac7-b9e3-4ee3-aa51-2dc394b500f5" ---@type string
      eve.ux.widget.Terminal:toggle_and_focus({
        uuid = termuuid,
        type = "runner",
        name = "code runner (mjs)",
        cwd = std.path.cwd(),
        autofocus = true,
        permanent = false,
      })

      std.timer.set_timeout(function()
        local termmeta = eve.term.get(termuuid) ---@type eve.builtin.term.IMeta|nil
        if termmeta ~= nil then
          handle(termmeta)
        end
      end, 1000)
    end,
  },
}

---@class fml.action.code
local M = {}

---@param force                         boolean
---@return nil
function M.run(force)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local extname = std.path.extname(filepath) ---@type string
  local key = string.sub(extname, 2) ---@type string

  local runner = runners[key]
  if runner == nil then
    std.reporter.warn({
      from = __module_name__,
      subject = "run",
      message = "Cannot find the runner by the given filepath.",
      details = { filepath = filepath, force = force, extname = extname, key = key },
    })
    return
  end

  runner.run(filepath, force)
end

return M
