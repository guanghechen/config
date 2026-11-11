local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_global(t, "stl", { env = { IS_WIN = false } })
bootstrap.with_global(t, "dot", {})
bootstrap.with_global(t, "era", {})

local data = require("era.m.diffview.data")

t:test("fetch: applies tracked stats from the shared status snapshot", function()
  local collect_opts = nil ---@type era.m.git.status.ICollectOpts|nil
  t:patch_table(era, "m", {
    git = {
      status = {
        collect = function(opts)
          collect_opts = opts
          return {
            await = function()
              local result = {
                status_map = {
                  ["/repo/a.lua"] = {
                    relative = "a.lua",
                    staged = { A = true },
                    unstaged = {},
                    staged_new_object_name = "index-a",
                  },
                  ["/repo/b.lua"] = {
                    relative = "b.lua",
                    staged = {},
                    unstaged = { M = true },
                    unstaged_old_object_name = "index-b",
                  },
                },
                numstats = {
                  staged = { ["a.lua"] = { insertions = 7, deletions = 0 } },
                  unstaged = { ["b.lua"] = { insertions = 2, deletions = 3 } },
                },
              }
              return {
                export = function()
                  return result
                end,
              }
            end,
          }
        end,
      },
    },
  })
  t:patch_table(dot, "path", {
    workspace = function()
      return "/repo"
    end,
  })

  local entries = data.fetch_diff_entries()
  local by_stage = {} ---@type table<string, era.m.diffview.IFileEntry>
  for _, entry in ipairs(entries) do
    by_stage[assert(entry.stage_type)] = entry
  end

  t.assert_true(collect_opts ~= nil and collect_opts.include_numstat == true, "single tracked snapshot requested")
  t.assert_eq(7, by_stage.staged.insertions, "staged insertions")
  t.assert_eq(0, by_stage.staged.deletions, "staged deletions")
  t.assert_eq(2, by_stage.unstaged.insertions, "unstaged insertions")
  t.assert_eq(3, by_stage.unstaged.deletions, "unstaged deletions")
  t.assert_eq("index-a", by_stage.staged.new_object_name, "staged snapshot identity")
  t.assert_eq("index-b", by_stage.unstaged.old_object_name, "unstaged snapshot identity")
end)

t:test("entries: equality ignores order and compares the complete semantic snapshot", function()
  local staged = {
    filepath = "new.lua",
    stage_type = "staged",
    status = "R",
    insertions = 7,
    deletions = 2,
    prev_filepath = "old.lua",
    old_object_name = "head-a",
    new_object_name = "index-a",
  } ---@type era.m.diffview.IFileEntry
  local unstaged = {
    filepath = "work.lua",
    stage_type = "unstaged",
    status = "M",
    insertions = 3,
    deletions = 1,
  } ---@type era.m.diffview.IFileEntry
  local entries = { staged, unstaged }

  t.assert_true(
    data.equal_diff_entries(entries, { vim.deepcopy(unstaged), vim.deepcopy(staged) }),
    "collection order ignored"
  )

  local mutations = {
    { "filepath", "other.lua" },
    { "stage_type", "unstaged" },
    { "status", "M" },
    { "insertions", 8 },
    { "deletions", 3 },
    { "prev_filepath", "older.lua" },
    { "old_object_name", "head-b" },
    { "new_object_name", "index-b" },
  }
  for _, mutation in ipairs(mutations) do
    local changed = vim.deepcopy(entries)
    changed[1][mutation[1]] = mutation[2]
    t.assert_false(data.equal_diff_entries(entries, changed), "changed " .. mutation[1])
  end

  t.assert_false(data.equal_diff_entries(entries, { staged }), "different entry count")
  t.assert_false(
    data.equal_diff_entries(
      { { filepath = "binary.dat", stage_type = "unstaged", status = "M" } },
      { { filepath = "binary.dat", stage_type = "unstaged", status = "M", insertions = 0, deletions = 0 } }
    ),
    "unknown and zero stats stay distinct"
  )
end)

t:test("status conversion keeps stage-specific rename sources", function()
  local entries = data.__convert_status_to_entries__({
    ["/repo/new.lua"] = {
      relative = "new.lua",
      stage = "mixed",
      staged = { R = true },
      unstaged = { R = true },
      staged_prev_relative = "head.lua",
      unstaged_prev_relative = "index.lua",
      staged_old_object_name = "head-old",
      staged_new_object_name = "index-new",
      unstaged_old_object_name = "index-old",
    },
  })

  local sources = {} ---@type table<string, string>
  local identities = {} ---@type table<string, era.m.diffview.IFileEntry>
  for _, entry in ipairs(entries) do
    sources[assert(entry.stage_type)] = assert(entry.prev_filepath)
    identities[assert(entry.stage_type)] = entry
  end
  t.assert_eq("head.lua", sources.staged, "staged source")
  t.assert_eq("index.lua", sources.unstaged, "unstaged source")
  t.assert_eq("head-old", identities.staged.old_object_name, "staged old identity")
  t.assert_eq("index-new", identities.staged.new_object_name, "staged new identity")
  t.assert_eq("index-old", identities.unstaged.old_object_name, "unstaged old identity")
  t.assert_nil(identities.unstaged.new_object_name, "unstaged worktree identity")

  local staged_only = data.__convert_status_to_entries__({
    ["/repo/plain.lua"] = {
      relative = "plain.lua",
      stage = "mixed",
      staged = { M = true },
      unstaged = { R = true },
      unstaged_prev_relative = "index.lua",
    },
  })
  for _, entry in ipairs(staged_only) do
    if entry.stage_type == "staged" then
      t.assert_nil(entry.prev_filepath, "staged source does not fall through")
    end
  end
end)

t:test("status conversion keeps staged deletion and same-path untracked replacement", function()
  local entries = data.__convert_status_to_entries__({
    ["/repo/replaced.lua"] = {
      relative = "replaced.lua",
      stage = "staged",
      staged = { D = true },
      unstaged = { ["?"] = true },
      codes = { D = true, ["?"] = true },
    },
  })

  local statuses = {} ---@type table<string, string>
  for _, entry in ipairs(entries) do
    statuses[assert(entry.stage_type)] = entry.status
  end

  t.assert_eq(2, #entries, "independent stage entries")
  t.assert_eq("D", statuses.staged, "staged deletion")
  t.assert_eq("?", statuses.unstaged, "unstaged replacement")
end)

t:test("status matching ignores order and diff statistics", function()
  local status_map = {
    ["a.lua"] = {
      relative = "a.lua",
      stage = "staged",
      staged = { M = true },
      staged_old_object_name = "head-a",
      staged_new_object_name = "index-a",
    },
    ["b.lua"] = { relative = "b.lua", codes = { ["?"] = true }, unstaged = { ["?"] = true } },
  }
  local entries = {
    { filepath = "b.lua", stage_type = "unstaged", status = "?", insertions = 3 },
    {
      filepath = "a.lua",
      stage_type = "staged",
      status = "M",
      deletions = 2,
      old_object_name = "head-a",
      new_object_name = "index-a",
    },
  }

  t.assert_true(data.matches_status_entries(entries, status_map), "matching status entries")
  entries[1].status = "D"
  t.assert_false(data.matches_status_entries(entries, status_map), "changed status entry")
  entries[1].status = "?"
  entries[2].new_object_name = "index-b"
  t.assert_false(data.matches_status_entries(entries, status_map), "changed staged blob identity")

  local renamed = {
    ["new.lua"] = {
      relative = "new.lua",
      stage = "staged",
      staged = { R = true },
      staged_prev_relative = "old.lua",
    },
  }
  t.assert_false(
    data.matches_status_entries({ { filepath = "new.lua", stage_type = "staged", status = "R" } }, renamed),
    "changed rename source"
  )
end)

t:run()
