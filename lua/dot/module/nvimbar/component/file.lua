local btn = ark.nvim.btn
local txt = ark.nvim.txt

local fileformat_text_map = {
  dos = "CRLF",
  mac = "CR",
  unix = "LF",
}

local __module_name__ = "dot.module.nvimbar.component.file" ---@type string

local fileformat_icon_map = {
  dos = dot.icon.os.dos,
  mac = dot.icon.os.mac,
  unix = dot.icon.os.nix,
}

---@type string
local fn_on_fileencoding_clicked = dot.G.register_anonymous_fn(function()
  dot.command.definitions.toggle.list:execute("fileencoding_local")
end) or ""

---@type string
local fn_on_fileformat_clicked = dot.G.register_anonymous_fn(function()
  dot.command.definitions.toggle.list:execute("fileformat_local")
end) or ""

---@class dot.module.nvimbar.component.file
local M = {}

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.encoding(position)
  local hln_text = position .. "_file_encoding_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:encoding",
    atomic = true,
    condition = function(context)
      return dot.filetype.is_sourcefile(context.filetype)
    end,
    render = function(context)
      local bufnr = context.bufnr ---@type integer
      local encoding = vim.bo[bufnr].fileencoding ---@type string

      local text = #encoding > 0 and encoding or "unknown" ---@type string
      local hl_text = txt(text, hln_text)

      local buftype = vim.bo[bufnr].buftype ---@type string
      if buftype == "" or buftype == "nowrite" then
        hl_text = btn(hl_text, fn_on_fileencoding_clicked)
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.format(position)
  local hln_text = position .. "_file_format_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:format",
    atomic = true,
    condition = function(context)
      return dot.filetype.is_sourcefile(context.filetype)
    end,
    render = function(context)
      local bufnr = context.bufnr ---@type integer
      local fileformat = vim.bo[bufnr].fileformat ---@type string

      local icon_fileformat = fileformat_icon_map[fileformat] or dot.icon.os.current ---@type string
      local text_fileformat = fileformat_text_map[fileformat] or fileformat ---@type string

      local text = string.format("%s %s", icon_fileformat, text_fileformat) ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      if vim.bo[bufnr].buftype == "" then
        hl_text = btn(hl_text, fn_on_fileformat_clicked)
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.indent(position)
  local hln_text = position .. "_file_indent_text" ---@type string
  local icon_shiftwidth = dot.icon.ui.Tab ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:indent",
    atomic = true,
    condition = function(context)
      return dot.filetype.is_sourcefile(context.filetype)
    end,
    render = function(context)
      local shiftwidth = vim.bo[context.bufnr].shiftwidth ---@type integer
      local text = string.format("%s %d", icon_shiftwidth, shiftwidth) ---@type string
      local hl_text = txt(text, hln_text)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.name(position)
  local hln_text = position .. "_file_name_text" ---@type string
  local hln_text_active = position .. "_file_name_text_active" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:name",
    atomic = true,
    render = function(context)
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      local is_mod = vim.bo[context.bufnr].modified ---@type boolean
      local text_mod = is_mod and " " or "" ---@type string
      if context.winnr ~= winnr_sourcefile then
        local text = context.fileicon .. " " .. context.filename .. text_mod ---@type string
        local hl_text = txt(text, hln_text) ---@type string
        return text, hl_text, true
      end

      local text_fileicon = context.fileicon .. " " ---@type string
      local hl_text_fileicon = txt(text_fileicon, context.fileicon_hl) ---@type string

      local text_filename = context.filename .. text_mod ---@type string
      local hl_text_filename = txt(text_filename, hln_text_active)

      local text = text_fileicon .. text_filename ---@type string
      local hl_text = hl_text_fileicon .. hl_text_filename ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.path(position)
  local hln_text = position .. "_file_path_text" ---@type string

  ---@type string
  local fn_on_filepath_clicked = dot.G.register_anonymous_fn(function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string

    dot.fn.select_copy_filepath({
      filepath = filepath,
      winopts = {
        relative = "editor",
        anchor = "SW",
        row = vim.o.lines - 1,
        col = 36,
      },
    })
  end) or ""

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:path",
    atomic = true,
    condition = function(context)
      return #context.filepath > 0 and context.filepath ~= "."
    end,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context)
      local meta = dot.buf.resolve(context.bufnr, false) ---@type dot.buf.IMeta|nil
      if meta == nil then
        return "", "", true
      end

      local relpath = meta.relpath ---@type string
      local text = context.fileicon .. " " .. relpath ---@type string
      local hl_text = btn(txt(text, hln_text), fn_on_filepath_clicked) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.readonly(position)
  local hln_readonly = position .. "_file_readonly" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:readonly",
    atomic = true,
    condition = function()
      return vim.bo.readonly
    end,
    render = function()
      local text = dot.icon.ui.Lock .. " [RO]" ---@type string
      local hl_text = txt(text, hln_readonly) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.size(position)
  local hln_text = position .. "_file_size_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:size",
    atomic = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filepath ~= prev_context.filepath
    end,
    render = function(context)
      if context.filepath == nil or context.filepath == "" then
        return "", "", true
      end

      if not yoz.path.is_exist(context.filepath) then
        return "", "", true
      end

      local text, err = yoz.fs.get_filesize(context.filepath)
      if err ~= nil then
        ark.reporter.error({
          from = __module_name__,
          subject = "get_filesize failed",
          details = {
            error = err,
            filepath = context.filepath,
          },
        })
      end
      text = text or ""
      local hl_text = txt(text, hln_text)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.status(position)
  local hln_text = position .. "_file_status_text" ---@type string

  ---@param bufnr                       integer
  ---@return string
  local function get_filestatus(bufnr)
    local summary = dot.git.hunk.get_summary(bufnr) ---@type dot.module.git.HunkSummary
    local text = "" ---@type string
    if summary.added > 0 then
      text = text .. " " .. dot.icon.git.Add .. " " .. summary.added ---@type string
    end
    if summary.changed > 0 then
      text = text .. " " .. dot.icon.git.Mod_alt .. " " .. summary.changed ---@type string
    end
    if summary.removed > 0 then
      text = text .. " " .. dot.icon.git.Remove .. " " .. summary.removed ---@type string
    end
    return text
  end

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:status",
    atomic = true,
    render = function(context)
      local text = get_filestatus(context.bufnr) ---@type string
      if #text < 1 then
        return "", "", true
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.type(position)
  local hln_text = position .. "_file_type_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "file:type",
    atomic = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.filetype ~= prev_context.filetype
    end,
    condition = function(context)
      return context.filetype and #context.filetype > 0
    end,
    render = function(context)
      local text = context.fileicon .. " " .. context.filetype ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
