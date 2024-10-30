local reporter = require("eve.std.reporter")

---@class t.eve.ICommand
---@field public uuid                   string
---@field public desc                   string
---@field public action                 fun(args?: string): nil
---@field public candidates             ?string[]

---@class t.eve.IRawCommand
---@field public uuid                   string
---@field public desc                   string
---@field public action                 fun(args?: string): nil
---@field public candidates             ?string[]
---@field public nargs                  ?0|1|"?"

---@type table<string, t.eve.ICommand>
local command_map = {}

---@class eve.std.commander
local M = {}

---@class eve.std.commander.uuids
M.uuids = {
  buf_close = "Fbufclose",
  buf_close_to_leftest = "Fbufclosetoleftest",
  buf_close_to_rightest = "Fbufclosetorightest",
  buf_close_others = "Fbufcloseothers",
  buf_focus = "Fbuffocus",
  buf_focus_1 = "Fbuffocus1",
  buf_focus_2 = "Fbuffocus2",
  buf_focus_3 = "Fbuffocus3",
  buf_focus_4 = "Fbuffocus4",
  buf_focus_5 = "Fbuffocus5",
  buf_focus_6 = "Fbuffocus6",
  buf_focus_7 = "Fbuffocus7",
  buf_focus_8 = "Fbuffocus8",
  buf_focus_9 = "Fbuffocus9",
  buf_focus_10 = "Fbuffocus10",
  buf_focus_left = "Fbuffocusleft",
  buf_focus_right = "Fbuffocusright",
  buf_new = "Fbufnew",
  buf_pin = "Fbufpin",
  buf_save = "Fbufsave",
  buf_swap_left = "Fbufswapleft",
  buf_swap_right = "Fbufswapright",
  copy_current_filepath = "Fcopycurrentfilepath",
  copy_current_filepath_relative = "Fcopycurrentfilepathrelative",
  debug_inspect = "Finspect",
  debug_inspect_pos = "Finspectpos",
  debug_inspect_state = "Finspectstate",
  debug_inspect_tree = "Finspecttree",
  find_buffers = "Ffindbuffers",
  find_explorer = "Ffindexplorer",
  find_files = "Ffindfiles",
  find_files_cwd = "Ffindfilescwd",
  find_files_directory = "Ffindfilesdirectory",
  find_files_workspace = "Ffindfilesworkspace",
  find_git_not_committed = "Ffindgitnotcommitted",
  find_highlights = "Ffindhighlights",
  find_pinned_files = "Ffindpinnedfiles",
  find_vim_options = "Ffindvimoptions",
  flight = "Fflight",
  git_diffview = "Fgitdiffview",
  git_file_history = "Fgitfilehistory",
  lazygit_cwd = "Flazygitcwd",
  lazygit_file_history = "Flazygitfilehistory",
  lazygit_workspace = "Flazygitworkspace",
  refresh_all = "Frefreshall",
  replace_files = "Freplacefiles",
  replace_files_buffer = "Freplacefilesbuffer",
  replace_files_cwd = "Freplacefilescwd",
  replace_files_directory = "Freplacefilesdirectory",
  replace_files_workspace = "Freplacefilesworkspace",
  resume = "Fresume",
  run = "Frun",
  search_files = "Fsearchfiles",
  search_files_buffer = "Fsearchfilesbuffer",
  search_files_cwd = "Fsearchfilescwd",
  search_files_directory = "Fsearchfilesdirectory",
  search_files_workspace = "Fsearchfilesworkspace",
  select_theme = "Fselecttheme",
  session_restore = "Fsessionrestore",
  session_save = "Fsessionsave",
  tab_close = "Ftabclose",
  tab_close_to_leftest = "Ftabclosetoleftest",
  tab_close_to_rightest = "Ftabclosetorightest",
  tab_close_others = "Ftabcloseothers",
  tab_focus = "Ftabfocus",
  tab_focus_1 = "Ftabfocus1",
  tab_focus_2 = "Ftabfocus2",
  tab_focus_3 = "Ftabfocus3",
  tab_focus_4 = "Ftabfocus4",
  tab_focus_5 = "Ftabfocus5",
  tab_focus_6 = "Ftabfocus6",
  tab_focus_7 = "Ftabfocus7",
  tab_focus_8 = "Ftabfocus8",
  tab_focus_9 = "Ftabfocus9",
  tab_focus_10 = "Ftabfocus10",
  tab_focus_left = "Ftabfocusleft",
  tab_focus_right = "Ftabfocusright",
  tab_new = "Ftabnew",
  tab_new_with_buf = "Ftabnewwithbuf",
  term_cwd = "Ftermcwd",
  term_directory = "Ftermdirectory",
  term_workspace = "Ftermworkspace",
}

---@param uuid                          string
---@return boolean
function M.should_be_command(uuid)
  for _, val in pairs(M.uuids) do
    if val == uuid then
      return true
    end
  end
  return false
end

---@param uuid                          string
---@param args                          ?string
---@param silent                        ?boolean
---@return t.eve.ICommand|nil
function M.execute(uuid, args, silent)
  local command = M.resolve(uuid, true) ---@type t.eve.ICommand|nil
  if command == nil then
    if not silent then
      reporter.error({
        from = "eve.std.commander",
        subject = "execute",
        message = "Cannot resolve the command by the given uuid",
        details = { uuid = uuid },
      })
    end
    return
  end
  command.action(args)
end

---@param raw_command                   t.eve.IRawCommand
---@param overwrite                     ?boolean
---@return eve.std.commander
function M.register(raw_command, overwrite)
  local uuid = raw_command.uuid ---@type string
  local desc = raw_command.desc ---@type string
  local action = raw_command.action ---@type fun(args?: string): nil
  local candidates = raw_command.candidates ---@type string[]|nil
  local nargs = raw_command.nargs or 0 ---@type 0|1|"?"
  local has_existed = command_map[uuid] ~= nil ---@type boolean

  if has_existed and not overwrite then
    reporter.warn({
      from = "eve.std.commander",
      subject = "register",
      message = "The command has been registered, please set the `overwrite` param to true if you want to replace it",
      details = { uuid = uuid, overwrite = overwrite },
    })
    return M
  end

  if not has_existed then
    vim.api.nvim_create_user_command(uuid, function(opts)
      M.execute(uuid, opts.args, false)
    end, {
      desc = desc,
      nargs = nargs,
      complete = nargs ~= 0
          and function(argLead)
            local command = M.resolve(uuid, true)
            if command ~= nil and command.candidates ~= nil then
              local pattern = "^" .. argLead ---@type string
              local options = command.candidates ---@type string[]

              local matches = {}
              for _, option in ipairs(options) do
                if option:match(pattern) then
                  table.insert(matches, option)
                end
              end
              return matches
            end
          end
        or nil,
    })
  end

  ---@type t.eve.ICommand
  local command = {
    uuid = uuid,
    desc = desc,
    action = action,
    candidates = candidates,
  }
  command_map[uuid] = command
  return M
end

---@param uuid                          string
---@param silent                        ?boolean
---@return t.eve.ICommand|nil
function M.resolve(uuid, silent)
  local command = command_map[uuid] ---@type t.eve.ICommand|nil
  if command == nil and not silent then
    reporter.warn({
      from = "eve.std.commander",
      subject = "resolve",
      message = "Cannot resolve the command by the given uuid",
      details = { uuid = uuid },
    })
  end
  return command
end

return M
