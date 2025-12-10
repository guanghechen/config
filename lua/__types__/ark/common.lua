---@meta

---@alias ark.t.T
---| any

---@generic T
---@alias ark.t.IFilter
---| fun(element: T, index: integer): boolean

---@class ark.t.IHighlight
---@field public lnum                   integer
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string

---@class ark.t.IHighlightInline
---@field public coll                   integer
---@field public colr                   integer
---@field public hlname                 string
