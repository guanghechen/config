---@class ghc.core.action.bookmark
local M = {}

function M.toggle_bookmark_on_current_line()
  require("bookmarks").bookmark_toggle()
end

function M.edit_bookmark_annotation_on_current_line()
  require("bookmarks").bookmark_ann()
end

function M.clear_bookmark_on_current_buffer()
  require("bookmarks").bookmark_clean()
end

function M.goto_prev_bookmark_on_current_buffer()
  require("bookmarks").bookmark_prev()
end

function M.goto_next_bookmark_on_current_buffer()
  require("bookmarks").bookmark_next()
end

function M.open_bookmarks_into_quickfix()
  require("bookmarks").bookmark_list()
end

return M
