---@meta

---@module 'yoz.uri'
---@class yoz.uri
local M = {}

---@class yoz.uri.UriParts
---@field public protocol               string
---@field public path                   string
---@field public hash                   string|nil

---@param uri                           string
---@return string|nil
function M.basename(uri) end

---@param protocol                      string
---@param path                          string
---@param hash                          string|nil
---@return string
function M.build(protocol, path, hash) end

---@param src                           string
---@return string
function M.decode(src) end

---@param src                           string
---@return string
function M.encode(src) end

---@param uri                           string
---@return string|nil
function M.extname(uri) end

---@param uri                           string
---@return string|nil
function M.hash(uri) end

---@param src                           string
---@return boolean
function M.is_data_uri(src) end

---@param from_uri                      string
---@param to_path                       string
---@return string|nil
function M.join(from_uri, to_path) end

---@param uri                           string
---@return string|nil
function M.normalize(uri) end

---@param uri                           string
---@return string|nil
function M.parent(uri) end

---@param uri                           string
---@return yoz.uri.UriParts|nil
function M.parse(uri) end

---@param uri                           string
---@return string|nil
function M.pathname(uri) end

---@param uri                           string
---@return string|nil
function M.protocol(uri) end

---@param from_uri                      string
---@param to_uri                        string
---@return string|nil
function M.relative(from_uri, to_uri) end

---@param path                          string
---@return string[]
function M.split(path) end

---@param uri                           string
---@return boolean
function M.validate(uri) end

return M
