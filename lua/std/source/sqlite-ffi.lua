---@diagnostic disable: invisible
local __module_name__ = "std.source.sqlite-ffi" ---@type string

local ffi = require("ffi")

ffi.cdef([[
  typedef struct sqlite3 sqlite3;
  typedef struct sqlite3_stmt sqlite3_stmt;

  int sqlite3_open_v2(const char *filename, sqlite3 **ppDb, int flags, const char *zVfs);
  int sqlite3_close(sqlite3 *db);
  int sqlite3_exec(sqlite3 *db, const char *sql, void *callback, void *arg, char **errmsg);
  int sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail);
  int sqlite3_step(sqlite3_stmt *pStmt);
  int sqlite3_finalize(sqlite3_stmt *pStmt);
  int sqlite3_reset(sqlite3_stmt *pStmt);
  int sqlite3_clear_bindings(sqlite3_stmt *pStmt);

  int sqlite3_bind_text(sqlite3_stmt *pStmt, int idx, const char *text, int n, void *destructor);
  int sqlite3_bind_int(sqlite3_stmt *pStmt, int idx, int value);
  int sqlite3_bind_null(sqlite3_stmt *pStmt, int idx);

  const unsigned char *sqlite3_column_text(sqlite3_stmt *pStmt, int iCol);
  int sqlite3_column_int(sqlite3_stmt *pStmt, int iCol);
  int sqlite3_column_type(sqlite3_stmt *pStmt, int iCol);
  int sqlite3_column_count(sqlite3_stmt *pStmt);
  const char *sqlite3_column_name(sqlite3_stmt *pStmt, int iCol);

  const char *sqlite3_errmsg(sqlite3 *db);
  int sqlite3_errcode(sqlite3 *db);
  void sqlite3_free(void *ptr);

  int sqlite3_busy_timeout(sqlite3 *db, int ms);
  int64_t sqlite3_last_insert_rowid(sqlite3 *db);
  int sqlite3_changes(sqlite3 *db);
]])

local SQLITE_OK = 0
local SQLITE_ROW = 100
local SQLITE_DONE = 101

local SQLITE_OPEN_READWRITE = 0x00000002
local SQLITE_OPEN_CREATE = 0x00000004
local SQLITE_OPEN_URI = 0x00000040
local SQLITE_OPEN_NOMUTEX = 0x00008000

local SQLITE_TRANSIENT = ffi.cast("void*", -1)

local SQLITE_INTEGER = 1
local SQLITE_FLOAT = 2
local SQLITE_TEXT = 3
local SQLITE_BLOB = 4
local SQLITE_NULL = 5

local sqlite3
do
  local lib_paths = {
    "sqlite3",
    "libsqlite3.so.0",
    "libsqlite3.so",
    "libsqlite3.dylib",
  }

  for _, path in ipairs(lib_paths) do
    local ok, lib = pcall(ffi.load, path)
    if ok then
      sqlite3 = lib
      break
    end
  end

  if sqlite3 == nil then
    error("Failed to load libsqlite3. Ensure SQLite3 is installed.")
  end
end

---@class std.source.sqlite.IConnection
---@field protected _db                 ffi.cdata* sqlite3 handle
---@field protected _filepath           string
---@field protected _prepared_stmts     table<string, ffi.cdata*> Cached prepared statements
local Connection = {}
Connection.__index = Connection

---Open database connection
---@param filepath                      string
---@return ffi.cdata* db_handle
local function open_database(filepath)
  local db_ptr = ffi.new("sqlite3*[1]")
  local flags = bit.bor(SQLITE_OPEN_READWRITE, SQLITE_OPEN_CREATE, SQLITE_OPEN_NOMUTEX)
  local rc = sqlite3.sqlite3_open_v2(filepath, db_ptr, flags, nil)

  if rc ~= SQLITE_OK then
    local errmsg = "Failed to open database"
    if db_ptr[0] ~= nil then
      errmsg = ffi.string(sqlite3.sqlite3_errmsg(db_ptr[0]))
      sqlite3.sqlite3_close(db_ptr[0])
    end
    error(string.format("%s: %s (code %d)", __module_name__, errmsg, rc))
  end

  return db_ptr[0]
end

---@param filepath                      string
---@param options                       {timeout_ms: integer|nil}|nil
---@return std.source.sqlite.IConnection
function Connection.new(filepath, options)
  options = options or {}
  local self = setmetatable({}, Connection)

  self._filepath = filepath
  self._prepared_stmts = {}
  self._db = open_database(filepath)

  local timeout_ms = type(options.timeout_ms) == "number" and options.timeout_ms or 5000
  sqlite3.sqlite3_busy_timeout(self._db, timeout_ms)

  ffi.gc(self._db, function(db)
    for _, stmt in pairs(self._prepared_stmts) do
      sqlite3.sqlite3_finalize(stmt)
    end
    sqlite3.sqlite3_close(db)
  end)

  return self
end

---Execute SQL without results
---@param sql                           string
---@return nil
function Connection:exec(sql)
  local errmsg_ptr = ffi.new("char*[1]")
  local rc = sqlite3.sqlite3_exec(self._db, sql, nil, nil, errmsg_ptr)

  if rc ~= SQLITE_OK then
    local errmsg = ffi.string(errmsg_ptr[0])
    sqlite3.sqlite3_free(errmsg_ptr[0])
    error(string.format("%s: %s (code %d)", __module_name__, errmsg, rc))
  end
end

---@class std.source.sqlite.IStatement
---@field protected _stmt               ffi.cdata* sqlite3_stmt handle
---@field protected _conn               std.source.sqlite.IConnection
local Statement = {}
Statement.__index = Statement

---Extract single row from current statement position
---@param stmt                          ffi.cdata* sqlite3_stmt
---@return table Row object {column_name = value}
local function extract_row(stmt)
  local row = {}
  local col_count = sqlite3.sqlite3_column_count(stmt)

  for i = 0, col_count - 1 do
    local col_name = ffi.string(sqlite3.sqlite3_column_name(stmt, i))
    local col_type = sqlite3.sqlite3_column_type(stmt, i)

    if col_type == SQLITE_NULL then
      row[col_name] = nil
    elseif col_type == SQLITE_INTEGER then
      row[col_name] = sqlite3.sqlite3_column_int(stmt, i)
    elseif col_type == SQLITE_TEXT then
      local text_ptr = sqlite3.sqlite3_column_text(stmt, i)
      row[col_name] = text_ptr ~= nil and ffi.string(text_ptr) or ""
    else
      error(string.format("%s: Unsupported column type: %d", __module_name__, col_type))
    end
  end

  return row
end

---Bind values to prepared statement (1-indexed)
---@param ...                           any Values to bind
---@return std.source.sqlite.IStatement
function Statement:bind(...)
  local values = {...}
  sqlite3.sqlite3_reset(self._stmt)
  sqlite3.sqlite3_clear_bindings(self._stmt)

  for i, value in ipairs(values) do
    local rc
    if value == nil or value == vim.NIL then
      rc = sqlite3.sqlite3_bind_null(self._stmt, i)
    elseif type(value) == "number" then
      if math.floor(value) == value then
        rc = sqlite3.sqlite3_bind_int(self._stmt, i, value)
      else
        error(string.format("%s: Float binding not implemented (use integer or text)", __module_name__))
      end
    elseif type(value) == "string" then
      rc = sqlite3.sqlite3_bind_text(self._stmt, i, value, #value, SQLITE_TRANSIENT)
    else
      error(string.format("%s: Unsupported bind type: %s", __module_name__, type(value)))
    end

    if rc ~= SQLITE_OK then
      local errmsg = ffi.string(sqlite3.sqlite3_errmsg(self._conn._db))
      error(string.format("%s: Bind failed: %s (code %d)", __module_name__, errmsg, rc))
    end
  end

  return self
end

---Execute and return all rows
---@return table[] Array of row objects {column_name = value}
function Statement:execute()
  local rows = {}

  while true do
    local rc = sqlite3.sqlite3_step(self._stmt)

    if rc == SQLITE_DONE then
      break
    elseif rc == SQLITE_ROW then
      rows[#rows + 1] = extract_row(self._stmt)
    else
      local errmsg = ffi.string(sqlite3.sqlite3_errmsg(self._conn._db))
      error(string.format("%s: Step failed: %s (code %d)", __module_name__, errmsg, rc))
    end
  end

  sqlite3.sqlite3_reset(self._stmt)
  return rows
end

---Execute and return first row or nil
---@return table|nil Row object or nil
function Statement:execute_one()
  local rc = sqlite3.sqlite3_step(self._stmt)

  if rc == SQLITE_DONE then
    sqlite3.sqlite3_reset(self._stmt)
    return nil
  elseif rc == SQLITE_ROW then
    local row = extract_row(self._stmt)
    sqlite3.sqlite3_reset(self._stmt)
    return row
  else
    local errmsg = ffi.string(sqlite3.sqlite3_errmsg(self._conn._db))
    sqlite3.sqlite3_reset(self._stmt)
    error(string.format("%s: Step failed: %s (code %d)", __module_name__, errmsg, rc))
  end
end

---Prepare SQL statement (cached)
---@param sql                           string
---@return std.source.sqlite.IStatement
function Connection:prepare(sql)
  if self._prepared_stmts[sql] ~= nil then
    return setmetatable({
      _stmt = self._prepared_stmts[sql],
      _conn = self,
    }, Statement)
  end

  local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
  local rc = sqlite3.sqlite3_prepare_v2(self._db, sql, #sql, stmt_ptr, nil)

  if rc ~= SQLITE_OK then
    local errmsg = ffi.string(sqlite3.sqlite3_errmsg(self._db))
    error(string.format("%s: Prepare failed: %s\nSQL: %s", __module_name__, errmsg, sql))
  end

  self._prepared_stmts[sql] = stmt_ptr[0]

  return setmetatable({
    _stmt = stmt_ptr[0],
    _conn = self,
  }, Statement)
end

---Begin transaction
---@return nil
function Connection:begin()
  self:exec("BEGIN TRANSACTION")
end

---Commit transaction
---@return nil
function Connection:commit()
  self:exec("COMMIT")
end

---Rollback transaction
---@return nil
function Connection:rollback()
  self:exec("ROLLBACK")
end

---Execute function in transaction (auto commit/rollback)
---@param fn                            fun(): nil
---@return nil
function Connection:transaction(fn)
  self:begin()
  local ok, err = pcall(fn)
  if ok then
    self:commit()
  else
    self:rollback()
    error(err)
  end
end

---Get number of rows affected by last statement
---@return integer
function Connection:changes()
  return sqlite3.sqlite3_changes(self._db)
end

return {
  Connection = Connection,
}
