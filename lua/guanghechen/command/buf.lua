local uuids = eve.commander.uuids

eve.commander
  .register({
    uuid = uuids.buf_close,
    desc = "buf: close current",
    action = function()
      ghc.action.buf.close_current()
    end,
  })
  .register({
    uuid = uuids.buf_close_to_leftest,
    desc = "buf: close to leftest",
    action = function()
      ghc.action.buf.close_to_leftest()
    end,
  })
  .register({
    uuid = uuids.buf_close_to_rightest,
    desc = "buf: close to rightest",
    action = function()
      ghc.action.buf.close_to_rightest()
    end,
  })
