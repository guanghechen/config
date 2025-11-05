local function spawn_json()
  local proc = std.Spawn.new({
    cmd = "printf",
    args = { '{"status":true,"value":42}' },
  })
  vim.wait(1000, function()
    return not proc:running()
  end)
  std.debug.log("spawn.json", {
    failed = proc:failed(),
    json = proc:json(),
    err = proc:err(),
  })
end

spawn_json()
