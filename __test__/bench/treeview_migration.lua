---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview_migration" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local kind, count, baseline = arg[1] or "list", tonumber(arg[2]) or 10000, arg[3]
baseline = baseline ~= "" and baseline or nil
assert(kind == "list" or kind == "directory", "expected list or directory")
local owns_fixture = arg[4] == nil
local directory = arg[4] or vim.fn.tempname()
if owns_fixture then
  vim.fn.mkdir(directory, "p")
end
if owns_fixture and kind == "directory" then
  for index = 1, count do
    vim.fn.writefile({}, directory .. string.format("/item-%06d.lua", index))
  end
end
local ui = require("__test__.support.ui").new({ timeout_ms = 30000 })
local samples = {}
local failure
ui.on_notification = function(method, args)
  if method == "migration_sample" then
    samples[args[1].stage] = args[1]
  elseif method == "migration_error" then
    failure = args[1]
  end
end
local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, path, kind, count, baseline = ...
    vim.opt.runtimepath:prepend(root)
    package.path=root.."/?.lua;"..root.."/?/init.lua;"..package.path
    if baseline then
      vim.opt.runtimepath:prepend(baseline)
      package.path=baseline.."/lua/?.lua;"..baseline.."/lua/?/init.lua;"..package.path
      package.cpath=baseline.."/lua/?.so;"..baseline.."/lua/?.dll;"..package.cpath
    end
    vim.api.nvim_set_current_dir(path)
    require("ark.bootstrap").setup()
    local metrics = require("__test__.bench.explorer.metrics")
    bench={kind=kind,count=count,path=path,errors={},records={}}
    stl.reporter.error=function(value) bench.errors[#bench.errors+1]=tostring(value.message) end
    local factory=era.m.picker.BasicComposer.new
    era.m.picker.BasicComposer.new=function(props)
      bench.props=props
      local value=factory(props)
      bench.basic=value
      bench.owner=props.result_tree
      return value
    end
    local set_lines=vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines=function(bufnr,first,last,strict,lines)
      if bench.stage and bench.basic and bufnr==bench.basic.result:get_bufnr() then
        bench.writes=bench.writes+1
        bench.written_rows=bench.written_rows+#lines
      end
      return set_lines(bufnr,first,last,strict,lines)
    end
    bench.items={}
    if kind=="list" then
      for index=1,count do
        local label=string.format("item-%06d.lua",index)
        bench.items[index]={uuid=tostring(index),text=label,text_lower=label,highlights={}}
      end
    end
    ---@param stage                     string
    ---@param rows                      integer
    ---@param row                       ?integer
    ---@param action                    fun(): nil
    ---@return nil
    function bench.start(stage,rows,row,action)
      collectgarbage("collect")
      bench.stage,bench.expected,bench.row=stage,rows,row
      bench.visible=nil
      bench.writes,bench.written_rows,bench.checks,bench.max_gap=0,0,0,0
      bench.usage=metrics.usage()
      bench.started=vim.uv.hrtime()
      bench.last_tick=bench.started
      action()
      bench.returned=vim.uv.hrtime()
    end
    local timer=vim.uv.new_timer()
    ---@return nil
    local function tick()
      if not bench.stage then return end
      local now=vim.uv.hrtime()
      bench.max_gap=math.max(bench.max_gap,(now-bench.last_tick)/1e6)
      bench.last_tick=now
      bench.checks=bench.checks+1
      local basic=bench.basic
      if not basic or basic.result.lnum_total:snapshot()~=bench.expected then return end
      local winnr=basic.result:get_winnr()
      if not winnr or not vim.api.nvim_win_is_valid(winnr) then return end
      if vim.api.nvim_buf_line_count(basic.result:get_bufnr())~=math.max(1,bench.expected) then return end
      if bench.row and vim.api.nvim_win_get_cursor(winnr)[1]~=bench.row then return end
      local owner=bench.owner
      if owner and (not owner.view or not owner.view:frame()) then return end
      if not bench.visible then
        vim.api.nvim__redraw({win=winnr,valid=false,flush=true})
        bench.visible=vim.uv.hrtime()
      end
      if owner then
        if not owner.view or not owner.view:frame() or owner.view:status().preparing then return end
        if kind=="directory" and not owner.data._native:is_settled() then return end
        if owner.state:status().revisions.state~=owner.view:frame():header().state_revision then return end
      end
      vim.api.nvim__redraw({win=winnr,valid=false,flush=true})
      now=vim.uv.hrtime()
      local usage=metrics.usage()
      local value={stage=bench.stage,started=bench.started,published=now,elapsed_ms=(now-bench.started)/1e6,
        visible=bench.visible,
        visible_ms=(bench.visible-bench.started)/1e6,flush_ms=(now-bench.started)/1e6,
        call_ms=(bench.returned-bench.started)/1e6,max_tick_gap_ms=bench.max_gap,checks=bench.checks,
        cpu_ms=(usage.cpu_us-bench.usage.cpu_us)/1000,main_ms=usage.main_us and (usage.main_us-bench.usage.main_us)/1000,
        writes=bench.writes,written_rows=bench.written_rows}
      bench.stage=nil
      vim.rpcnotify(1,"migration_sample",value)
    end
    timer:start(2,2,vim.schedule_wrap(function()
      local ok,error=pcall(tick)
      if not ok then timer:stop(); vim.rpcnotify(1,"migration_error",tostring(error)) end
    end))
    ---@return nil
    function bench.open()
      bench.start("open",kind=="directory" and count+1 or count,nil,function()
        if kind=="directory" then
          require("era.fn.find-explorer")(path.."/item-000001.lua")
        else
          local observable=stl.c.Observable.from_value
          bench.picker=era.m.picker.ListComposer.new({name="migration bench",title="migration bench",permanent=true,
            search_pattern=observable(""),flag_fuzzy=observable(false),flag_regex=observable(false),flag_case_sensitive=observable(false)})
          bench.picker:reset_data({items=bench.items})
          bench.picker:focus()
        end
      end)
    end
    ---@return nil
    function bench.filter()
      bench.start("filter",1,nil,function() bench.basic.finder:set_content("item-000050") end)
    end
    ---@return nil
    function bench.clear()
      bench.start("clear",kind=="directory" and count+1 or count,nil,function() bench.basic.finder:set_content("") end)
    end
    ---@return nil
    function bench.cursor()
      bench.start("cursor",kind=="directory" and count+1 or count,20,function() bench.basic.result:set_lnum_current(20) end)
    end
    ---@return nil
    function bench.reopen()
      bench.start("reopen",kind=="directory" and count+1 or count,nil,function() bench.basic:hide(); bench.basic:focus() end)
    end
    ---@return table
    function bench.memory()
      local before=vim.uv.hrtime()
      collectgarbage("collect")
      local result=metrics.memory()
      result.gc_ms=(vim.uv.hrtime()-before)/1e6
      result.errors=bench.errors
      timer:stop(); timer:close()
      return result
    end
  ]],
    { root, directory, kind, count, baseline }
  )
  for _, stage in ipairs({ "open", "filter", "clear", "cursor", "reopen" }) do
    ui:rpc("nvim_exec_lua", "bench." .. stage .. "()", {})
    local deadline = vim.uv.hrtime() + 30000000000
    assert(
      vim.wait(30000, function()
        assert(not failure, failure)
        if vim.uv.hrtime() >= deadline then
          error("benchmark stage timeout: " .. stage .. " " .. vim.inspect(ui:rpc(
            "nvim_exec_lua",
            [[
          return {stage=bench.stage,count=bench.basic and bench.basic.result.lnum_total:snapshot(),
            frame=bench.owner and bench.owner.view and bench.owner.view:frame() and vim.inspect(bench.owner.view:frame():header()),
            status=bench.owner and bench.owner.state and vim.inspect(bench.owner.state:status()),
            checks=bench.checks,errors=bench.errors,errmsg=vim.v.errmsg,messages=vim.fn.execute("messages")}
        ]],
            {}
          )))
        end
        local sample = samples[stage]
        return sample ~= nil
      end, 1),
      "missing sample: " .. stage
    )
  end
  return {
    kind = kind,
    count = count,
    baseline = baseline,
    samples = samples,
    memory = ui:rpc("nvim_exec_lua", "return bench.memory()", {}),
  }
end, debug.traceback)
ui:close()
if owns_fixture then
  vim.fn.delete(directory, "rf")
end
assert(ok, result)
io.write(vim.json.encode(result), "\n")
