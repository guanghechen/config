---@meta

---@module 'yoz.im'
---@alias yoz.im.InputMethod
---| "English"
---| "Chinese"

---@alias yoz.im.Snapshot string

---@class yoz.im.ISetupOptions
---@field public executable             string

---@class yoz.im
---@field public setup?                 fun(options: yoz.im.ISetupOptions): boolean|nil, string|nil WSL-only repository bridge configuration.
local M = {}

---Returns the current platform IM source token.
---On macOS this is a TIS source ID; on Windows it is a full decimal HKL; on WSL it is the helper's decimal LANGID.
---@return string|nil
---@return string|nil
function M.current() end

---Requests selection of an IM source by its platform token.
---A true result means the operating system accepted the request; visibility may be asynchronous.
---@param source_id                     string
---@return boolean|nil
---@return string|nil
function M.select(source_id) end

---Captures the backend-visible IM source token for later restoration.
---@return yoz.im.Snapshot|nil
---@return string|nil
function M.capture() end

---Restores a snapshot returned by `capture()`.
---@param snapshot                      yoz.im.Snapshot
---@return boolean|nil
---@return string|nil
function M.restore(snapshot) end

---Returns whether a captured source maps to the semantic input method.
---@param snapshot                      yoz.im.Snapshot
---@param input_method                  yoz.im.InputMethod
---@return boolean
function M.is_input_method(snapshot, input_method) end

---Returns the semantic input method mapped from the current platform source.
---@return yoz.im.InputMethod|nil
---@return string|nil
function M.get_input_method() end

---Selects the platform source mapped from a semantic input method.
---@param input_method                  yoz.im.InputMethod
---@return boolean|nil
---@return string|nil
function M.set_input_method(input_method) end

return M
