---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.view.result_locations" ---@type string

local t = require("__test__.support.harness").new("era.view.result_locations")

t:test("location spans are prepared for the viewport and metadata-only updates reach both surfaces", function()
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 120, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root)
    package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
    package.cpath = root .. "/lua/?.so;" .. package.cpath
    require("ark.bootstrap").setup()
    native = require("__test__.support.result_tree")
    local Paths = require("era.view.result_paths")
    local Files = require("era.view.result_files")
    spans, errors, formats = {}, {}, 0
    stl.reporter.error = function(value) errors[#errors+1] = value.message end
    vim.api.nvim_set_hl(0, "LocationOld", {fg="#ff0000"})
    vim.api.nvim_set_hl(0, "LocationNew", {fg="#00ff00"})
    local format = Files.present_location
    Files.present_location = function(...)
      formats = formats + 1
      return format(...)
    end
    local mark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, opts)
      if opts.ephemeral and (opts.hl_group == "LocationOld" or opts.hl_group == "LocationNew") then
        spans[bufnr] = spans[bufnr] or {}
        spans[bufnr][row] = {col=col, last=opts.end_col, highlight=opts.hl_group}
      end
      return mark(bufnr, namespace, row, col, opts)
    end
    owner = Files.new({name="location viewport", tree=Paths.new()})
    owner:reset_filepaths("/location-viewport", {"many.lua"})
    file_key = Paths.key("/location-viewport/many.lua")
    for index=1,2000 do
      owner:add_location(file_key, {
        locationuuid="match:" .. index, lnum=index, col=1, text="needle",
        highlights={{coll=0, colr=6, hlname="LocationOld"}},
      })
    end
    request = {mode="tree", rootuuid=Paths.key("/location-viewport")}
    native.publish(owner, request)
    assert(formats == 0, "offscreen records must not prepare highlight spans")
    local frame = owner:frame()
    assert(frame:node(frame:source():id("match:1000")).fields.highlights == nil)
    main_bufnr = vim.api.nvim_create_buf(false, true)
    local winnr = vim.api.nvim_open_win(main_bufnr, false, {relative="editor",row=0,col=0,width=50,height=6})
    owner:mount(winnr, main_bufnr, function() end)
    native.await(owner:ready())
    preview = era.view.PickerPreview.new({
      name="location preview", diagnostic_scope="location preview", relative_number=false, keymaps={},
      tree=function() return {owner=owner,key=file_key,foldempty=false,title="locations"} end,
      draw=function() error("expected a native location preview") end,
    })
    preview:create_win({border="none",winhighlight=""},{row=0,col=60,width=50,height=6})
    preview:mark_content_dirty()
  ]],
    { assert(vim.uv.cwd()) }
  )
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
      local other = preview:get_bufnr()
      return spans[main_bufnr] and spans[main_bufnr][1] and spans[other] and spans[other][0] or false
    ]],
      {}
    )
  end, 5000)
  local initial = ui:rpc(
    "nvim_exec_lua",
    "return {formats=formats,main=spans[main_bufnr][1],preview=spans[preview:get_bufnr()][0]}",
    {}
  )
  t.assert_true(initial.formats < 500, "only visible locations should be formatted")
  t.assert_eq("LocationOld", initial.main.highlight)
  t.assert_eq(6, initial.main.last - initial.main.col)
  t.assert_eq("LocationOld", initial.preview.highlight)

  ui:rpc(
    "nvim_exec_lua",
    [[
    previous = owner:retrieve("match:1")
    revision = owner:frame():header().data_revision
    owner.entries["match:1"].highlights = {{coll=1,colr=4,hlname="LocationNew"}}
    owner:invalidate()
    local prepare = owner.view._options.prepare_frame
    owner.view._options.prepare_frame = function(...)
      if not released then
        return stl.c.Future.new(function(resolve) release = resolve end)
      end
      return prepare(...)
    end
    publication = owner:publish(vim.deepcopy(request))
  ]],
    {}
  )
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return release ~= nil", {})
  end, 5000)
  t.assert_false(
    ui:rpc("nvim_exec_lua", "return publication:is_done()", {}),
    "publication waits for viewport preparation"
  )
  ui:rpc("nvim_exec_lua", "released=true; release(function() end)", {})
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      [[
      return publication:is_done() and spans[main_bufnr][1].highlight == "LocationNew"
        and spans[preview:get_bufnr()][0].highlight == "LocationNew"
    ]],
      {}
    )
  end, 5000)
  local result = ui:rpc(
    "nvim_exec_lua",
    [[
    assert(not publication:is_failed(), publication:get_error())
    return {main=spans[main_bufnr][1],preview=spans[preview:get_bufnr()][0],
      unchanged=owner:frame():header().data_revision == revision,old=previous.highlights[1].hlname,errors=errors}
  ]],
    {}
  )
  t.assert_true(result.unchanged, "location spans need no native record mutation")
  t.assert_eq("LocationOld", result.old, "the prior metadata snapshot remains immutable")
  t.assert_eq(3, result.main.last - result.main.col)
  t.assert_eq(3, result.preview.last - result.preview.col)
  t.assert_eq(0, #result.errors, vim.inspect(result.errors))

  ui:rpc(
    "nvim_exec_lua",
    [[
    local prepare = preview._tree_view._options.prepare_frame
    preview._tree_view._options.prepare_frame = function(...)
      return prepare(...):then_(function(commit)
        if not preview_released then
          return stl.c.Future.new(function(resolve)
            release_preview = function() resolve(commit) end
          end)
        end
        return commit
      end)
    end
    owner.entries["match:1"].text = "updated needle"
    owner:invalidate()
    publication = owner:publish(vim.deepcopy(request))
  ]],
    {}
  )
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return publication:is_done() and release_preview ~= nil", {})
  end, 5000)
  t.assert_true(
    ui:rpc(
      "nvim_exec_lua",
      [[
    local shown = preview._tree_view:frame():header().data_revision
    assert(shown ~= owner:frame():header().data_revision)
    return owner._versions[shown] ~= nil
  ]],
      {}
    ),
    "a lagging preview retains its displayed metadata"
  )
  ui:rpc(
    "nvim_exec_lua",
    [[
    spans[preview:get_bufnr()] = {}
    vim.api.nvim__redraw({win=preview:get_winnr(),valid=false})
  ]],
    {}
  )
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return spans[preview:get_bufnr()][0] ~= nil", {})
  end, 5000)
  ui:rpc("nvim_exec_lua", "preview_released=true; release_preview()", {})
  t.wait_until(function()
    return ui:rpc("nvim_exec_lua", "return vim.tbl_count(owner._versions) == 1", {})
  end, 5000, "obsolete preview metadata is reclaimed after its replacement publishes")
end)

t:run()
