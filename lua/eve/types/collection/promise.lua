---@class eve.t.collection.IPromise
---@field public resolve                fun(value: unknown): eve.t.collection.IPromise
---@field public reject                 fun(reason: unknown): eve.t.collection.IPromise
---@field public settled                fun(self: eve.t.collection.IPromise): boolean
---@field public snapshot               fun(self: eve.t.collection.IPromise): unknown, unknown
---@field public xthen                  fun(self: eve.t.collection.IPromise, on_fulfilled: eve.t.collection.promise.IOnFulfilled): eve.t.collection.IPromise
---@field public xcatch                 fun(self: eve.t.collection.IPromise, on_rejected: eve.t.collection.promise.IOnRejected): eve.t.collection.IPromise
---@field public xfinally               fun(self: eve.t.collection.IPromise, on_finally: eve.t.collection.promise.IOnFinally): eve.t.collection.IPromise

---@alias eve.t.collection.promise.ISettled
---| 'fulfilled'
---|'rejected'

---@alias eve.t.collection.promise.IOnFulfilled
---| fun(value: unknown): unknown

---@alias eve.t.collection.promise.IOnRejected
---| fun(reason: unknown): unknown

---@alias eve.t.collection.promise.IOnFinally
---| fun(settled: eve.t.collection.promise.ISettled, value: unknown|nil, reason: unknown|nil): nil

---@alias eve.t.collection.promise.IResolve
---| fun(value: unknown): nil

---@alias eve.t.collection.promise.IReject
---| fun(reason: unknown): nil

---@class eve.t.collection.promise.ICallback
---@field public type                   'fulfilled'|'rejected'|'finally'
---@field public callback               fun(): nil
