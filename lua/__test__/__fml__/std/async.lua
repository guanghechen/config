local function test_debounce()
  local callback_count = 0 ---@type integer
  local run_count = 0 ---@type integer

  local a = fml.scheduler.debounce({
    name = "__test__.fml.std.async",
    delay = 100,
    callback = function()
      callback_count = callback_count + 1
    end,
    fn = function(callback)
      run_count = run_count + 1
      callback(true, nil)
    end,
  })

  local function run()
    a.schedule()
  end

  vim.defer_fn(run, 50)
  vim.defer_fn(run, 100)
  vim.defer_fn(run, 250)
  vim.defer_fn(run, 300)
  vim.defer_fn(run, 350)
  vim.defer_fn(run, 475)
  vim.defer_fn(run, 500)
  vim.defer_fn(run, 650)
  vim.defer_fn(run, 700)

  vim.defer_fn(function()
    fml.debug.log({
      callback_count = callback_count,
      run_count = run_count,
    })
  end, 3000)
end

test_debounce()
