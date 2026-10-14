---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.memory" ---@type string

local Data = require("__test__.bench.cmp.data")
local Rpc = require("__test__.support.rpc")
local M = {}

---@param options                       table
---@return table
function M.run(options)
  local result = {
    cases = {},
    note = "fresh processes, GC before snapshots; RSS includes allocator arenas and shared library pages, Lua heap excludes Rust allocations",
  }
  for _, count in ipairs({ 10000, 50000 }) do
    for _, engine in ipairs({ "era", "blink" }) do
      local samples = {}
      for _ = 1, 7 do
        local rpc = Rpc.new(options.root)
        local ok, value = xpcall(function()
          return rpc:lua(
            [[
            local options, count, engine = ...
            vim.opt.runtimepath:prepend(options.root)
            vim.opt.runtimepath:append(options.blink)
            package.path = options.root .. '/?.lua;' .. options.root .. '/?/init.lua;' .. package.path
            if options.baseline then
              vim.opt.runtimepath:prepend(options.baseline)
              package.preload.yoz = assert(package.loadlib(options.baseline .. '/bin/nix.yoz.so', 'luaopen_yoz'))
            end
            local Data = require('__test__.bench.cmp.data')
            local started = vim.uv.hrtime()
            local native = engine == 'era' and require('yoz').completion or require('blink.cmp.fuzzy.rust')
            local load_ms = (vim.uv.hrtime() - started) / 1e6
            local labels = Data.labels(count)
            local raw = Data.items(labels)
            collectgarbage('collect')
            local before_rss, before_lua = Data.rss_kib(), collectgarbage('count')
            started = vim.uv.hrtime()
            local matcher
            if engine == 'era' then matcher = native.new(labels) else native.set_provider_items('bench', raw) end
            local construction_ms = (vim.uv.hrtime() - started) / 1e6
            collectgarbage('collect')
            local cached_rss, cached_lua = Data.rss_kib(), collectgarbage('count')
            for _ = 1, 20 do
              if matcher then
                matcher:query_packed('c')
              else
                native.fuzzy('c', 1, { 'bench' }, { max_typos = 0, sorts = { 'score', 'sort_text' } })
              end
            end
            collectgarbage('collect')
            return {
              load_ms = load_ms, construction_ms = construction_ms,
              cache_rss_kib = cached_rss - before_rss, cache_lua_kib = cached_lua - before_lua,
              queried_rss_kib = Data.rss_kib() - before_rss, queried_lua_kib = collectgarbage('count') - before_lua,
            }
          ]],
            options,
            count,
            engine
          )
        end, debug.traceback)
        rpc:close()
        assert(ok, value)
        samples[#samples + 1] = value
      end
      local summary = {}
      for key in pairs(samples[1]) do
        local values = {}
        for _, sample in ipairs(samples) do
          values[#values + 1] = sample[key]
        end
        summary[key] = Data.stats(values)
      end
      result.cases[#result.cases + 1] = { candidates = count, engine = engine, summary = summary }
    end
  end
  return result
end

return M
