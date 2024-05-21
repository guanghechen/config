---@class guanghechen
local M = {
  clazz = {
    BatchDisposable = require("guanghechen.disposable.BatchDisposable"),
    Disposable = require("guanghechen.disposable.Disposable"),
    Observable = require("guanghechen.observable.Observable"),
    SafeBatchHandler = require("guanghechen.disposable.SafeBatchHandler"),
    Subscriber = require("guanghechen.subscriber.Subscriber"),
    Subscribers = require("guanghechen.subscriber.Subscribers"),
    Timer = require("guanghechen.timer.Timer"),
    Viewmodel = require("guanghechen.viewmodel.Viewmodel"),
  },
  util = {
    comparator = require("guanghechen.util.comparator"),
    debounce = require("guanghechen.util.debounce"),
    disposable = require("guanghechen.util.disposable"),
    fs = require("guanghechen.util.fs"),
    json = require("guanghechen.util.json"),
    md5 = require("guanghechen.util.md5"),
    misc = require("guanghechen.util.misc"),
    navigator = require("guanghechen.util.navigator"),
    observable = require("guanghechen.util.observable"),
    os = require("guanghechen.util.os"),
    path = require("guanghechen.util.path"),
    regex = require("guanghechen.util.regex"),
    reporter = require("guanghechen.util.reporter"),
    selection = require("guanghechen.util.selection"),
    table = require("guanghechen.util.table"),
  },
}

return M
