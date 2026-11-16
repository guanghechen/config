---@meta

---@diagnostic disable-next-line: unused-local
local __module_name__ = "yoz.pairs" ---@type string

---@alias yoz.pairs.Class "delimiter"|"string"|"block_string"|"line_comment"|"block_comment"|"inline_span"|"block_span"

--- A buffer's pair tokens, kept in sync with its line edits. Rows and columns are zero-based; columns are bytes.
---@class yoz.pairs.Document
local Document = {}

--- Replaces lines `first` to `old_end` (exclusive) with `lines`, as `on_lines` reports an edit.
---@param first                         integer
---@param old_end                       integer
---@param lines                         string[]
---@return integer revision
function Document:edit(first, old_end, lines) end

--- The width a tab counts in indents.
---@param tab_width                     integer
---@return integer revision
function Document:set_tab_width(tab_width) end

---@return integer
function Document:revision() end

---@return integer
function Document:line_count() end

--- Delimiters from (`first_row`, `first_col`) up to (`last_row`, `last_col`), exclusive, as consecutive row, column,
--- end column and height, which is -1 for an unmatched delimiter.
---@param first_row                     integer
---@param first_col                     integer
---@param last_row                      integer
---@param last_col                      integer
---@return integer[]
function Document:highlights(first_row, first_col, last_row, last_col) end

--- The class of the string, comment or span a position lies in; nil in code and within an opening or closing.
---@param row                           integer
---@param col                           integer
---@return yoz.pairs.Class|nil
function Document:inside(row, col) end

--- The pair of the token at a position: row, column and length of the opening, then of the closing.
---@param row                           integer
---@param col                           integer
---@return integer|nil open_row
---@return integer|nil open_col
---@return integer|nil open_len
---@return integer|nil close_row
---@return integer|nil close_col
---@return integer|nil close_len
function Document:match_pair(row, col) end

--- The pair of the token at a position, or off any token the innermost pair around it.
---@param row                           integer
---@param col                           integer
---@return integer|nil open_row
---@return integer|nil open_col
---@return integer|nil open_len
---@return integer|nil close_row
---@return integer|nil close_col
---@return integer|nil close_len
function Document:surrounding_pair(row, col) end

--- An unmatched closing delimiter after the position at its level, which typing `open` there would pair with.
---@param open                          string
---@param close                         string
---@param row                           integer
---@param col                           integer
---@return integer|nil row
---@return integer|nil col
function Document:unmatched_closing_after(open, close, row, col) end

--- An unmatched opening delimiter before the position at its level, which typing `close` there would pair with.
---@param open                          string
---@param close                         string
---@param row                           integer
---@param col                           integer
---@return integer|nil row
---@return integer|nil col
function Document:unmatched_opening_before(open, close, row, col) end

---@class yoz.pairs.IToken
---@field public col                    integer
---@field public kind                   "opening"|"closing"|"non_pair"
---@field public class                  yoz.pairs.Class
---@field public open                   string
---@field public close                  ?string
---@field public span                   ?string
---@field public height                 ?integer Absent when unmatched.

--- Every token of a row, for inspection.
---@param row                           integer
---@return yoz.pairs.IToken[]
function Document:tokens(row) end

---@class yoz.pairs
local M = {}

--- The language a buffer of `filetype` parses with.
---@param filetype                      string
---@return string|nil
function M.language(filetype) end

---@param language                      string
---@param tab_width                     integer
---@return yoz.pairs.Document
function M.new(language, tab_width) end

return M
