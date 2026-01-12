---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.run_code" ---@type string

---@class era.fn.run_code.IRunner
---@field public run                    fun(filepath: string, force: boolean): nil

---@class era.fn.run_code.IRunners
---@field public eventstream            era.fn.run_code.IRunner
---@field public excalidraw             era.fn.run_code.IRunner
---@field public html                   era.fn.run_code.IRunner
---@field public json                   era.fn.run_code.IRunner
---@field public jsonl                  era.fn.run_code.IRunner
---@field public log                    era.fn.run_code.IRunner
---@field public md                     era.fn.run_code.IRunner
---@field public svg                    era.fn.run_code.IRunner
---@field public txt                    era.fn.run_code.IRunner
---
---@field public lua                    era.fn.run_code.IRunner
---@field public mjs                    era.fn.run_code.IRunner

local YOZ_SERVER_PORT = type(vim.env.YOZ_SERVER_PORT) == "string" and vim.env.YOZ_SERVER_PORT or "7071" ---@type string

---@param filepath                      string
---@param force                         boolean
local function open_filepath_within_yoz(filepath, force)
  local url = string.format(
    "https://localhost:%s/api/file/switch?filepath=%s&force=%s",
    YOZ_SERVER_PORT,
    yoz.uri.encode(filepath),
    force and "true" or "false"
  )
  vim.system({ "curl", "-k", "-X", "POST", url }, { detach = true })
end

---@type era.fn.run_code.IRunners
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

  ----------------------------------------------------------------------------------------------------

  http = {
    run = function(filepath)
      local script_path = dot.path.locate_app_config_home("ora/cli/http.mjs") ---@type string
      local cmd = { "node", script_path, filepath } ---@type string[]

      local group = yoz.fn.uuid() ---@type string
      local terminated = false ---@type boolean
      local spinner_step = 200 ---@type integer
      local spinner_timer = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
      local output = "Starting HTTP request...\n" ---@type string

      ---@param level                   ?stl.e.LogLevelEnum
      ---@return nil
      local function update_notification(level)
        local message = terminated and output or (output .. " " .. stl.anim.spinner(spinner_step)) ---@type string
        stl.reporter.log(level or "INFO", {
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
          stl.timer.clear_timer(spinner_timer)
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

  ----------------------------------------------------------------------------------------------------
  lua = {
    run = function(filepath)
      vim.cmd("luafile " .. filepath)
    end,
  },
  mjs = {
    run = function(filepath)
      ---@param termmeta                era.m.term.IMeta
      ---@return nil
      local function handle(termmeta)
        local bufnr = termmeta.bufnr ---@type integer|nil
        if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
          local channel_id = vim.api.nvim_get_option_value("channel", { buf = bufnr }) ---@type integer
          local cmd = "node " .. vim.fn.shellescape(filepath) .. "\n" ---@type string
          vim.fn.chansend(channel_id, cmd)
        end
      end

      local termuuid = "9b2efac7-b9e3-4ee3-aa51-2dc394b500f5" ---@type string
      era.m.term.widget:toggle_and_focus({
        uuid = termuuid,
        type = "runner",
        name = "code runner (mjs)",
        cwd = dot.path.cwd(),
        autofocus = true,
        permanent = false,
      })

      stl.timer.delay(function()
        local termmeta = era.m.term.state.get(termuuid) ---@type era.m.term.IMeta|nil
        if termmeta ~= nil then
          handle(termmeta)
        end
      end, 1000)
    end,
  },
}

---@param force                         boolean
---@return nil
local function run_code(force)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
  local extname = yoz.path.extname(filepath) ---@type string
  local key = string.sub(extname, 2) ---@type string

  local runner = runners[key]
  if runner == nil then
    stl.reporter.warn({
      from = __module_name__,
      subject = "run",
      message = "Cannot find the runner by the given filepath.",
      details = { filepath = filepath, force = force, extname = extname, key = key },
    })
    return
  end

  runner.run(filepath, force)
end

return run_code
