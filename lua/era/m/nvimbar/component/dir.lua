---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.dir" ---@type string

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---@class era.m.nvimbar.component.dir.IPathTarget
---@field public id                     integer
---@field public path                   string

-- Current and displayed snapshots own targets; these lookups do not extend their lifetime.
local targets_by_id = setmetatable({}, { __mode = "v" }) ---@type table<integer, era.m.nvimbar.component.dir.IPathTarget>
local targets_by_path = setmetatable({}, { __mode = "v" }) ---@type table<string, era.m.nvimbar.component.dir.IPathTarget>
local target_id = 0
local fn_open_explorer = dot.G.register_anonymous_fn(function(id)
  local target = targets_by_id[id]
  if target ~= nil then
    dot.command.definitions.find.explorer:execute(vim.fn.fnameescape(target.path))
  end
end)

---@class era.m.nvimbar.component.dir
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.path(position)
  local hln_blur_sep = position .. "_dir_path_blur_sep" ---@type string
  local hln_blur_text = position .. "_dir_path_blur_text" ---@type string
  local hln_focus_sep = position .. "_dir_path_focus_sep" ---@type string
  local hln_focus_text = position .. "_dir_path_focus_text" ---@type string

  local sep = stl.icon.fillchars.foldclose .. " " ---@type string
  local hl_blur_sep = txt(sep, hln_blur_sep) ---@type string
  local hl_focus_sep = txt(sep, hln_focus_sep) ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "dir:path",

    refresh = function(context)
      local meta = dot.buf.resolve(context.bufnr, false) ---@type dot.buf.IMeta|nil
      if meta == nil then
        return { text = "", hltext = "" }
      end

      local relpath_pieces = vim.split(meta.relpath, stl.env.PATH_SEP, { plain = true }) ---@type string[]
      local tabnr = context.tabnr ---@type integer
      local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      local hln_text = winnr_sourcefile == context.winnr and hln_focus_text or hln_blur_text ---@type string
      local hl_text_sep = winnr_sourcefile == context.winnr and hl_focus_sep or hl_blur_sep ---@type string

      local text = "" ---@type string
      local hl_text = "" ---@type string
      local targets = {} ---@type era.m.nvimbar.component.dir.IPathTarget[]
      local N = #relpath_pieces - 1 ---@type integer
      for i = 1, N, 1 do
        local piece = relpath_pieces[i] ---@type string
        local path = dot.path.resolve(context.cwd, table.concat(relpath_pieces, stl.env.PATH_SEP, 1, i))
        local target = targets_by_path[path]
        if target == nil then
          target_id = target_id + 1
          target = { id = target_id, path = path }
          targets_by_id[target_id], targets_by_path[path] = target, target
        end
        targets[i] = target
        local hl_text_piece = btn(txt(piece, hln_text), fn_open_explorer, target.id) ---@type string

        text = text .. piece .. sep
        hl_text = hl_text .. hl_text_piece .. hl_text_sep
      end
      return { text = text, hltext = hl_text, targets = targets }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.path_prominent(position)
  local hln_icon = position .. "_dir_path_prominent_icon" ---@type string
  local hln_text = position .. "_dir_path_prominent_text" ---@type string

  local icon = " " .. stl.icon.os.current .. " " ---@type string
  local sep = stl.env.PATH_SEP ---@type string
  local hl_icon = txt(icon, hln_icon) ---@type string

  local width_icon = vim.api.nvim_strwidth(icon) ---@type integer
  local width_sep = vim.api.nvim_strwidth(sep) ---@type integer

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "dir:path_prominent",

    condition = function(context)
      local tabnr = context.tabnr ---@type integer
      local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
      return context.winnr == winnr_sourcefile
    end,
    refresh = function(context)
      local meta = dot.buf.resolve(context.bufnr, false) ---@type dot.buf.IMeta|nil
      if meta == nil then
        return nil
      end

      local relpath_pieces = vim.split(meta.relpath, stl.env.PATH_SEP, { plain = true }) ---@type string[]
      local cwd_name = yoz.path.basename(context.cwd) ---@type string
      return { pieces = relpath_pieces, cwd_name = cwd_name }
    end,
    render = function(snapshot, _, remain_width)
      local relpath_pieces, cwd_name = snapshot.pieces, snapshot.cwd_name
      local N = #relpath_pieces - 1 ---@type integer
      if N < 1 then
        local text = cwd_name .. " " ---@type string
        local hl_text = hl_icon .. txt(text, hln_text) ---@type string
        text = icon .. text
        return text, hl_text
      end

      local is_absolute = relpath_pieces[1] == "" ---@type boolean
      local left_text = is_absolute and "" or cwd_name ---@type string

      local remain_count = is_absolute and N - 1 or N ---@type integer
      remain_width = remain_width - vim.api.nvim_strwidth(left_text) - width_icon - width_sep - N
      if remain_width < 1 then
        local text = cwd_name .. " " ---@type string
        local hl_text = hl_icon .. txt(text, hln_text) ---@type string
        text = icon .. text
        return text, hl_text
      end

      local right_text = "" ---@type string
      local _start_index = is_absolute and 2 or 1 ---@type integer
      for i = N, _start_index, -1 do
        local piece = relpath_pieces[i] ---@type string
        local w = vim.api.nvim_strwidth(piece) + width_sep ---@type integer
        if remain_width <= w then
          break
        end

        if i == N then
          right_text = piece .. " "
        else
          right_text = piece .. sep .. right_text
        end

        remain_width = remain_width - w
        remain_count = remain_count - 1
      end

      if remain_count > 0 then
        local omitter = string.rep(".", remain_count)
        right_text = omitter .. sep .. right_text
      end

      local text = left_text .. sep .. right_text ---@type string
      local hl_text = hl_icon .. txt(text, hln_text)
      text = icon .. text
      return text, hl_text
    end,
  }
  return component
end

return M
