---@class t.eve.collection.IPromise
---@field public resolve                fun(value: unknown): t.eve.collection.IPromise
---@field public reject                 fun(reason: unknown): t.eve.collection.IPromise
---@field public settled                fun(self: t.eve.collection.IPromise): boolean
---@field public snapshot               fun(self: t.eve.collection.IPromise): unknown, unknown
---@field public xthen                  fun(self: t.eve.collection.IPromise, on_fulfilled: t.eve.collection.promise.IOnFulfilled): t.eve.collection.IPromise
---@field public xcatch                 fun(self: t.eve.collection.IPromise, on_rejected: t.eve.collection.promise.IOnRejected): t.eve.collection.IPromise
---@field public xfinally               fun(self: t.eve.collection.IPromise, on_finally: t.eve.collection.promise.IOnFinally): t.eve.collection.IPromise

---@alias t.eve.collection.promise.ISettled
---| 'fulfilled'
---|'rejected'

---@alias t.eve.collection.promise.IOnFulfilled
---| fun(value: unknown): unknown

---@alias t.eve.collection.promise.IOnRejected
---| fun(reason: unknown): unknown

---@alias t.eve.collection.promise.IOnFinally
---| fun(settled: t.eve.collection.promise.ISettled, value: unknown|nil, reason: unknown|nil): nil

---@alias t.eve.collection.promise.IResolve
---| fun(value: unknown): nil

---@alias t.eve.collection.promise.IReject
---| fun(reason: unknown): nil

---@class t.eve.collection.promise.ICallback
---@field public type                   'fulfilled'|'rejected'|'finally'
---@field public callback               fun(): nil
