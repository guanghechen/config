---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.view.result_icons" ---@type string

local t = require("__test__.support.harness").new("era.view.result_icons")

for _, consumer in ipairs({ "picker", "searcher", "diffview" }) do
  t:test(consumer .. " draws cached folder icons from each surface's expansion state", function()
    local ui = require("__test__.support.ui").new()
    t:defer(function()
      ui:close()
    end)
    ui:rpc("nvim_ui_attach", 120, 30, { rgb = true, ext_linegrid = true })
    local expected = ui:rpc(
      "nvim_exec_lua",
      [[
      local root, consumer = ...
      vim.opt.runtimepath:prepend(root)
      package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
      package.cpath = root .. "/lua/?.so;" .. package.cpath
      require("ark.bootstrap").setup()
      native = require("__test__.support.result_tree")
      errors, icon_marks, chevrons = {}, {}, {}
      lookups = {file={}, directory={}}
      stl.reporter.error = function(value) errors[#errors+1] = value.message end
      local closed, highlight = stl.fileicon.get_directory_icon("src")
      local file = stl.fileicon.get_file_icon("src")
      for _, kind in ipairs({"file", "directory"}) do
        local lookup = stl.fileicon["get_" .. kind .. "_icon"]
        stl.fileicon["get_" .. kind .. "_icon"] = function(name, ...)
          lookups[kind][name] = (lookups[kind][name] or 0) + 1
          return lookup(name, ...)
        end
      end
      local set_extmark = vim.api.nvim_buf_set_extmark
      vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, options)
        local chunk = options.virt_text and options.virt_text[1]
        if options.ephemeral and options.virt_text_pos == "overlay" and chunk then
          if options.priority == 130 then
            icon_marks[bufnr] = icon_marks[bufnr] or {}
            icon_marks[bufnr][row+1] = chunk
          elseif chunk[1] == "▾" or chunk[1] == "▸" then
            chevrons[bufnr] = (chevrons[bufnr] or 0) + 1
          end
        end
        return set_extmark(bufnr, namespace, row, col, options)
      end
      local paths = {"a/src/one.lua", "b/src"}
      for index=1,1000 do paths[#paths+1] = string.format("zdir%04d/one.lua", index) end
      result_bufnr = vim.api.nvim_create_buf(false, true)
      if consumer == "diffview" then
        local pane = require("era.m.diffview.pane.tree")
        local commits = require("era.m.diffview.pane.commits")
        local files = {}
        for _, path in ipairs(paths) do files[#files+1] = {filepath=path, status="M"} end
        local commit = {hash="icons", abbrev_hash="icons", author="A", date=0, message="icons", files=files}
        owner = pane.new()
        native.await(pane.apply(result_bufnr, commits.render({commit}, {
          viewtype="tree", foldempty=true, include_files={icons=true},
        }), owner))
        preview_root = "commit:icons"
        directory_key = pane.key(preview_root, "a/src", true)
        file_key = pane.key(preview_root, "b/src", false)
        owner:set_expansion(preview_root, true, false)
        native.await(owner:ready())
      else
        local Paths = require("era.view.result_paths")
        local Files = require(consumer == "picker" and "era.view.result_files" or "era.m.searcher.view.filetree")
        owner = Files.new({name="folder icons", tree=Paths.new()})
        owner:reset_filepaths("/icons", paths, false)
        owner:add_location(Paths.key("/icons/a/src/one.lua"), {lnum=2, col=0})
        preview_root, directory_key, file_key = Paths.key("/icons"), Paths.key("/icons/a/src"), Paths.key("/icons/b/src")
        native.publish(owner, {rootuuid=preview_root, foldempty=true})
      end
      assert(next(lookups.file) == nil and next(lookups.directory) == nil, "import resolved offscreen icons")
      revision = owner:frame():header().data_revision
      local winnr = vim.api.nvim_open_win(result_bufnr, false, {relative="editor", row=0, col=0, width=55, height=14})
      owner:mount(winnr, result_bufnr, function() end)
      native.await(owner:ready())
      preview = era.view.PickerPreview.new({
        name="folder preview", diagnostic_scope="folder preview", relative_number=false, keymaps={},
        tree=function() return {owner=owner, key=preview_root, foldempty=true, title="preview"} end,
        draw=function() error("directory preview must use its native surface") end,
      })
      preview:create_win({border="none", winhighlight=""}, {row=0, col=60, width=55, height=14})
      preview:mark_content_dirty()
      assert(vim.wait(5000, function() return preview._tree_view and preview._tree_view:frame() end, 1))
      return {open=stl.icon.filetype.FolderOpen, closed=closed, highlight=highlight, file=file}
    ]],
      { assert(vim.uv.cwd()), consumer }
    )

    ---@param code                      string
    ---@return any
    local function eval(code)
      return ui:rpc("nvim_exec_lua", code, {})
    end

    ---@param glyph                     string
    ---@return nil
    local function check(glyph)
      local actual
      t.wait_until(function()
        ui:rpc("nvim_command", "redraw")
        actual = eval([[
        local main = owner:frame()
        local other = preview._tree_view:frame()
        local row = main:position(main:source():id(directory_key))
        local other_row = other:position(other:source():id(directory_key))
        local file_row = main:position(main:source():id(file_key))
        return {
          main=icon_marks[result_bufnr] and icon_marks[result_bufnr][row],
          preview=icon_marks[preview:get_bufnr()] and icon_marks[preview:get_bufnr()][other_row],
          file=icon_marks[result_bufnr] and icon_marks[result_bufnr][file_row],
          directory_lookups=lookups.directory.src, file_lookups=lookups.file.src,
          same_revision=revision == main:header().data_revision, errors=errors,
        }
        ]])
        return actual.main and actual.main[1] == glyph
      end, 5000, "the published folder icon did not reach the viewport")
      t.assert_eq(glyph, actual.main and actual.main[1])
      t.assert_eq(expected.highlight, actual.main[2])
      t.assert_eq(expected.open, actual.preview and actual.preview[1], "preview keeps independent expansion")
      t.assert_eq(expected.file, actual.file and actual.file[1], "same file and directory names have separate caches")
      t.assert_eq(1, actual.directory_lookups)
      t.assert_eq(1, actual.file_lookups)
      t.assert_true(actual.same_revision, "icon changes do not import records")
      t.assert_eq(0, #actual.errors, vim.inspect(actual.errors))
    end

    check(expected.open)
    eval([[owner:collapse(directory_key, "collapse", false); native.await(owner:ready())]])
    check(expected.closed)
    eval([[owner:collapse(directory_key, "expand", false); native.await(owner:ready())]])
    check(expected.open)
    local count = eval("return vim.tbl_count(lookups.directory)")
    t.assert_true(count < 40, "only viewport directory names are resolved: " .. count)
    t.assert_eq(0, eval("return chevrons[preview:get_bufnr()] or 0"), "preview does not draw a fallback chevron")
    local main_chevrons = eval("return chevrons[result_bufnr] or 0")
    if consumer == "diffview" then
      t.assert_true(main_chevrons > 0, "commit headers retain their generic expand indicator")
    else
      t.assert_eq(0, main_chevrons, "file results do not draw fallback chevrons")
      eval([[
        refreshed_paths = vim.list_slice(owner.source._reset.paths)
        owner:reset_filepaths("/icons", refreshed_paths, false)
        owner:add_location(require("era.view.result_paths").key("/icons/a/src/one.lua"), {lnum=2,col=0})
        native.publish(owner, {rootuuid=preview_root, foldempty=true})
      ]])
      check(expected.open)
      eval([[
        refreshed_paths[#refreshed_paths+1] = "fresh.lua"
        owner:reset_filepaths("/icons", refreshed_paths, false)
        native.publish(owner, {rootuuid=preview_root, foldempty=true})
      ]])
      t.wait_until(function()
        return eval("return lookups.directory.src == 2 and lookups.file.src == 2")
      end, 5000, "a changed path set must invalidate its viewport icon cache")
    end
  end)
end

t:run()
