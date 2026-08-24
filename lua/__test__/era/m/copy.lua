---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/copy.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.copy")
local copied = nil ---@type string|nil
local bufnr_sourcefile = nil ---@type integer|nil
local winnr_sourcefile = nil ---@type integer|nil

bootstrap.with_runtime(t, {
  stl = {
    nvim = {
      buf = {
        retrieve_visual_lnum_range = function()
          local lnum_start = vim.fn.getpos("v")[2] ---@type integer
          local lnum_end = vim.fn.getpos(".")[2] ---@type integer
          return math.min(lnum_start, lnum_end), math.max(lnum_start, lnum_end)
        end,
      },
      fn = {
        copy = function(content)
          copied = content
        end,
      },
    },
    reporter = {
      error = function() end,
      info = function() end,
    },
  },
  dot = {
    command = {
      definitions = {
        copy = {
          filepath = { candidates = { "absolute", "relative", "filename" } },
          filepath_location = { candidates = { "absolute", "relative", "filename" } },
        },
      },
    },
    path = {
      cwd = function()
        return "/workspace"
      end,
      relative = function(_, filepath)
        return filepath:gsub("^/workspace/", "")
      end,
    },
    tab = {
      retrieve_bufnr_sourcefile = function()
        return bufnr_sourcefile or vim.api.nvim_get_current_buf()
      end,
      retrieve_winnr_sourcefile = function()
        return winnr_sourcefile or vim.api.nvim_get_current_win()
      end,
    },
  },
  yoz = {
    path = {
      basename = function(filepath)
        return filepath:match("([^/]+)$") or filepath
      end,
    },
  },
})

local copy = assert(loadfile("lua/era/m/copy.lua"))()

---@param filepath                      string
---@return integer
local function use_buffer(filepath)
  local bufnr_previous = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  if filepath ~= "" then
    vim.api.nvim_buf_set_name(bufnr, filepath)
  end
  local lines = {} ---@type string[]
  for lnum = 1, 60 do
    lines[lnum] = "line " .. lnum
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_buf(0, bufnr)

  t:_register_cleanup(function()
    if vim.api.nvim_buf_is_valid(bufnr_previous) then
      vim.api.nvim_win_set_buf(0, bufnr_previous)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
end

t:test("copies the current line with a GitHub location fragment", function()
  use_buffer("/workspace/lua/test.lua")
  vim.api.nvim_win_set_cursor(0, { 23, 0 })
  copied = nil
  local options = nil ---@type table|nil
  local on_choice = nil ---@type (fun(choice: string|nil): nil)|nil

  t:patch_table(vim.ui, "select", function(_, opts, callback)
    options = opts
    on_choice = callback
  end)

  copy.copy_filepath_location()

  t.assert_eq("Copy Filepath (#L23)", assert(options).prompt, "picker title")
  assert(on_choice)("relative")
  t.assert_eq("lua/test.lua#L23", copied, "clipboard content")
end)

t:test("sorts a reversed visual selection into a GitHub line range", function()
  use_buffer("/workspace/lua/test.lua")
  copied = nil
  local options = nil ---@type table|nil
  local on_choice = nil ---@type (fun(choice: string|nil): nil)|nil

  t:patch_table(vim.ui, "select", function(_, opts, callback)
    options = opts
    on_choice = callback
  end)

  vim.cmd("normal! 42Gv23G")
  copy.copy_filepath_location()

  t.assert_eq("Copy Filepath (#L23-L42)", assert(options).prompt, "picker title")
  assert(on_choice)("filename")
  t.assert_eq("test.lua#L23-L42", copied, "clipboard content")
end)

t:test("uses a single-line fragment for a visual selection within one line", function()
  use_buffer("/workspace/lua/test.lua")
  copied = nil
  local on_choice = nil ---@type (fun(choice: string|nil): nil)|nil

  t:patch_table(vim.ui, "select", function(_, _, callback)
    on_choice = callback
  end)

  vim.cmd("normal! 23G0v5l")
  copy.copy_filepath_location()

  assert(on_choice)("relative")
  t.assert_eq("lua/test.lua#L23", copied, "clipboard content")
end)

t:test("copies an absolute filepath when the scope is provided", function()
  use_buffer("/workspace/lua/test.lua")
  vim.api.nvim_win_set_cursor(0, { 7, 0 })
  copied = nil

  copy.copy_filepath_location("absolute")

  t.assert_eq("/workspace/lua/test.lua#L7", copied, "clipboard content")
end)

t:test("uses the tab sourcefile filepath and cursor outside the sourcefile buffer", function()
  use_buffer("diffview://null")
  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vsplit")
  winnr_sourcefile = vim.api.nvim_get_current_win()
  bufnr_sourcefile = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr_sourcefile, "/workspace/lua/test.lua")
  local lines = {} ---@type string[]
  for lnum = 1, 30 do
    lines[lnum] = "source " .. lnum
  end
  vim.api.nvim_buf_set_lines(bufnr_sourcefile, 0, -1, false, lines)
  vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr_sourcefile)
  vim.api.nvim_win_set_cursor(winnr_sourcefile, { 17, 0 })
  vim.api.nvim_set_current_win(winnr_current)

  t:_register_cleanup(function()
    if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
      vim.api.nvim_win_close(winnr_sourcefile, true)
    end
    if bufnr_sourcefile ~= nil and vim.api.nvim_buf_is_valid(bufnr_sourcefile) then
      vim.api.nvim_buf_delete(bufnr_sourcefile, { force = true })
    end
    bufnr_sourcefile = nil
    winnr_sourcefile = nil
  end)

  copied = nil
  copy.copy_filepath_location("relative")

  t.assert_eq("lua/test.lua#L17", copied, "clipboard content")
end)

t:run()
