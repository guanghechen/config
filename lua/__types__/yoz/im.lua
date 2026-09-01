---@meta

---@module 'yoz.im'
---@alias yoz.im.Snapshot string

---@class yoz.im.ISetupOptions
---@field public executable             string

---@class yoz.im
---@field public setup?                 fun(options: yoz.im.ISetupOptions): boolean|nil, string|nil WSL-only repository bridge configuration.
local M = {}

---Captures the current platform input-source ID without changing it.
---macOS uses a TIS source ID; Windows and WSL use a full decimal HKL.
---@return yoz.im.Snapshot|nil
---@return string|nil
function M.capture() end

---Captures the current source and ensures an English-capable source in one platform operation.
---A non-nil snapshot is preserved even when selection fails.
---@return yoz.im.Snapshot|nil
---@return boolean ready
---@return string|nil
function M.capture_and_select_english() end

---Restores an exact snapshot returned by `capture()` or `capture_and_select_english()`.
---@param snapshot                      yoz.im.Snapshot
---@return boolean|nil
---@return string|nil
function M.restore(snapshot) end

---Returns whether a captured source is English-capable.
---@param snapshot                      yoz.im.Snapshot
---@return boolean
function M.is_english(snapshot) end

return M
