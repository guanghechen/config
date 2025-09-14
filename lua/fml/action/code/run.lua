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
    "https://localhost:%s/api/file/switch?filepath=%s&force=%s",
    YOZ_SERVER_PORT,
    std.string.escape_url_component(filepath),
    force and "true" or "false"
  )
  vim.system({ "curl", "-k", "-X", "POST", url }, { detach = true })
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

  http = {
    run = function(filepath)
      local script_path = std.path.locate_app_config_home("ora/cli/http.mjs") ---@type string
      local cmd = { "node", script_path, filepath } ---@type string[]

      local group = oxi.fn.uuid() ---@type string
      local terminated = false ---@type boolean
      local spinner_step = 200 ---@type integer
      local spinner_timer = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
      local output = "Starting HTTP request...\n" ---@type string

      ---@param level                   ?std.e.LogLevelEnum
      ---@return nil
      local function update_notification(level)
        local message = terminated and output or (output .. " " .. std.fn.spinner(spinner_step)) ---@type string
        std.reporter.log(level or "INFO", {
          from = __module_name__,
          subject = filepath,
          message = message,
          group = group,
        })
      end

      ---@return nil
      local function clear_spinner()
        terminated = true
        if spinner_timer then
          spinner_timer:stop()
          spinner_timer:close()
          spinner_timer = nil
        end
      end

      -- Start spinner timer
      if spinner_timer then
        spinner_timer:start(0, 200, vim.schedule_wrap(update_notification))
      end

      update_notification()
      vim.system(cmd, {
        text = true,
        stdout = function(err, data)
          if err then
            output = output .. "\n" .. tostring(err)
          end
          if data then
            output = output .. data
          end
          update_notification()
        end,
        stderr = function(err, data)
          if err then
            output = output .. "\n" .. tostring(err)
          end
          if data then
            output = output .. data
          end
          update_notification("ERROR")
        end,
      }, function()
        clear_spinner()
        update_notification()
      end)
      update_notification()
    end,
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
