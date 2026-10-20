---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.ranking" ---@type string

local Data = require("__test__.bench.cmp.data")
local M = {}

---@param items                         table[]
---@return string
local function fingerprint(items)
  local records = {}
  for index, item in ipairs(items) do
    -- Corpus labels are unique; occurrence keys identify positions within a response.
    records[index] = item.frecency_key .. "\0" .. string.format("%.17g", item.score)
  end
  return vim.fn.sha256(table.concat(records, "\n"))
end

---@param options                       table
---@return table
function M.run(options)
  local Runtime = require("__test__.support.cmp.runtime")
  Runtime.setup(options.baseline)
  local Rank = require("era.keystroke.cmp.rank")
  local Lsp = require("era.keystroke.cmp.source.lsp")
  local history = dot.context.frecency.completions
  local client = { id = 9001, name = "bench_1", offset_encoding = "utf-16" }
  local result = {
    construction = {},
    queries = {},
    note = "ms; separate fresh-list normalization and snapshot preparation, reused snapshots for warm rank; history off/empty/64 accepted entries; production MD5 keys on both versions; fingerprint covers ordered content keys and final scores; standalone fuzzy includes packed full-result transfer; full GC outside each sample",
  }
  for _, count in ipairs({ 1000, 10000, 50000 }) do
    for _, dense in ipairs({ false, true }) do
      local corpus = dense and "dense_typo" or "identifiers"
      io.stdout:write("  " .. corpus .. " / " .. count .. "\n")
      io.stdout:flush()
      local labels = Data.labels(count, dense)
      local raw = Data.items(labels)
      local context = Runtime.context("")
      local items, groups
      local normalize = Data.measure({
        normalize = function()
          items = Lsp.response(context, client, raw).items
          return items
        end,
      }, options.samples)
      local prepare = Data.measure({
        prepare = function()
          groups = Rank.prepare(items)
          return groups
        end,
      }, options.samples)
      result.construction[#result.construction + 1] = {
        corpus = corpus,
        candidates = count,
        sha256 = vim.fn.sha256(table.concat(labels, "\n")),
        normalize = normalize.normalize,
        prepare = prepare.prepare,
      }
      local matcher = yoz.completion.new(labels)
      for _, state in ipairs({ "off", "empty", "populated" }) do
        history:load({ MAX_TIMESTAMPS = 10, items = {} })
        if state == "populated" then
          for index = 1, 64 do
            local item = items[(index * 7919) % count + 1]
            history:access("lua\0" .. item.frecency_key)
          end
        end
        for _, query in ipairs(dense and { "", "compleiton" } or { "", "get", "getCompletion", "zzzzqqqq" }) do
          local current = Runtime.context(query)
          vim.api.nvim_buf_set_lines(0, 0, -1, false, { query, labels[1], labels[math.floor(count / 2)] })
          local active_history = state ~= "off" and history or nil
          local timings = Data.measure({
            rank = function()
              return Rank.filter(current, groups, active_history)
            end,
            fuzzy_packed = function()
              return matcher:query_packed(query)
            end,
          }, options.samples)
          local ranked = Rank.filter(current, groups, active_history)
          result.queries[#result.queries + 1] = {
            corpus = corpus,
            candidates = count,
            query = query,
            history = state,
            count = #ranked,
            fingerprint = fingerprint(ranked),
            timings = timings,
          }
        end
      end
    end
  end
  return result
end

return M
