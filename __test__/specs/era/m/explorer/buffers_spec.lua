---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.buffers" ---@type string

local fixture = require("__test__.support.explorer").new("era.m.explorer.buffers")
local t, await = fixture.t, fixture.await
local buffers = require("era.m.explorer.buffers")

for _, case in ipairs({
  {
    name = "Windows drive",
    windows = true,
    source = [[C:\alias\old]],
    target = [[C:\alias\new]],
    physical = [[\\?\C:\work\old]],
    destination = [[\\?\C:\work\new]],
    from = "C:/work/old",
    to = "C:/work/new",
  },
  {
    name = "Windows UNC",
    windows = true,
    source = [[\\server\alias\old]],
    target = [[\\server\alias\new]],
    physical = [[\\?\UNC\server\share\old]],
    destination = [[\\?\UNC\server\share\new]],
    from = "//server/share/old",
    to = "//server/share/new",
  },
  {
    name = "Unix literal backslash and filename bytes",
    windows = false,
    source = "/alias/old\\" .. string.char(255),
    target = "/alias/new\\" .. string.char(255),
    physical = "/work/old\\" .. string.char(255),
    destination = "/work/new\\" .. string.char(255),
    from = "/work/old\\" .. string.char(255),
    to = "/work/new\\" .. string.char(255),
  },
}) do
  t:test(case.name .. " paths agree across LSP preparation and alias buffer synchronization", function()
    t:patch_table(stl.env, "IS_WIN", case.windows)
    local bufnr = vim.api.nvim_create_buf(true, false)
    t:defer(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "unsaved content" })
    local name = case.from .. "/$literal space #文.lua"
    local get_name = vim.api.nvim_buf_get_name
    -- Emulate only the platform filename; the buffer and URI encoder are real.
    t:patch_table(vim.api, "nvim_buf_get_name", function(current)
      return current == bufnr and name or get_name(current)
    end)
    local renamed = {}
    t:patch_table(era.m.lsp.event, "rename_buf", function(from, to)
      renamed[#renamed + 1] = { from, to }
    end)
    local sent = {}
    t:patch_table(vim.lsp, "get_clients", function()
      return {
        {
          offset_encoding = "utf-16",
          supports_method = function()
            return true
          end,
          request = function(_, method, changes, done)
            sent[method] = changes
            done(nil, nil)
            return true, 1
          end,
          notify = function(_, method, changes)
            sent[method] = changes
          end,
        },
      }
    end)
    local confirmation = { token = "move", source = case.physical, target = case.destination }
    t.assert_true(await(buffers.prepare({
      status = function()
        return { confirmation = confirmation }
      end,
    }, confirmation)))
    buffers.sync({
      operation = "move",
      report = function(message)
        error(message)
      end,
    }, {
      status = "success",
      source = case.source,
      target = case.target,
      source_physical = case.physical,
      target_physical = case.destination,
    })
    local expected = {
      files = { { oldUri = vim.uri_from_fname(case.from), newUri = vim.uri_from_fname(case.to) } },
    }
    for _, method in ipairs({ "workspace/willRenameFiles", "workspace/didRenameFiles" }) do
      t.assert_true(vim.deep_equal(expected, sent[method]), method .. ": " .. vim.inspect(sent[method]))
    end
    t.assert_true(vim.deep_equal({ { name, case.to .. "/$literal space #文.lua" } }, renamed))
    t.assert_eq(case.physical, confirmation.source)
    t.assert_eq(case.destination, confirmation.target)
    t.assert_true(vim.deep_equal({ "unsaved content" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)))
    t.assert_true(vim.api.nvim_get_option_value("modified", { buf = bufnr }))
  end)
end

t:run()
