local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local Future = require("stl.c.future")
local diff = require("era.m.git.diff")
local hunk = assert(loadfile("lua/era/m/git/hunk.lua"))()

local t = harness.new()

---Gives the actions an attached buffer whose stage, unstage and reset end with `results`, and returns the reports
---they make.
---@param results                       { stage: table, unstage: table, reset: table }
---@return table<string, table[]>
local function with_results(results)
  bootstrap.with_global(t, "era", {
    m = {
      git = {
        buffer = {
          is_attached = function()
            return true
          end,
          stage_hunk = function()
            return Future.resolve(results.stage)
          end,
          unstage_hunk = function()
            return Future.resolve(results.unstage)
          end,
          reset_hunk = function()
            return results.reset.ok, results.reset.err
          end,
        },
      },
    },
  })
  return bootstrap.with_reporter(t)
end

t:test("actions: stage, unstage and reset warn once with the reason they were refused", function()
  local reports = with_results({
    stage = { ok = false, err = "The index changed since the hunk was drawn; try again" },
    unstage = { ok = false, err = "The selection range does not contain any staged changes" },
    reset = { ok = false, err = "No hunk at cursor" },
  })

  hunk.stage()
  hunk.unstage()
  hunk.reset()

  t.assert_same({
    "The index changed since the hunk was drawn; try again",
    "The selection range does not contain any staged changes",
    "No hunk at cursor",
  }, bootstrap.messages(reports.warn))
end)

t:test("actions: a failure Git reported itself and a success are not reported again", function()
  local reports = with_results({ stage = { ok = false }, unstage = { ok = true }, reset = { ok = true } })

  hunk.stage()
  hunk.unstage()
  hunk.reset()

  t.assert_eq(0, #reports.warn + #reports.error, "no reports")
end)

t:test("signs: a following deletion does not rewrite a change sign", function()
  local hunks = diff.run_diff({ "a", "b", "c", "" }, { "A", "b", "" })
  local signs = hunk.calc_signs_all(hunks)

  t.assert_eq(2, #hunks, "authoritative hunks")
  t.assert_eq("change", signs[1].type, "change sign")
  t.assert_eq(1, signs[1].lnum, "change line")
  t.assert_eq("delete", signs[2].type, "delete sign")
  t.assert_eq(2, signs[2].lnum, "delete anchor")
end)

t:test("signs: excess removed lines remain a changedelete", function()
  local hunks = diff.run_diff({ "a", "b", "c", "" }, { "A", "" })
  local signs = hunk.calc_signs_all(hunks)

  t.assert_eq(1, #hunks, "one unequal hunk")
  t.assert_eq("changedelete", signs[1].type, "combined sign")
end)

t:test("textobject: returns linewise unstaged hunk regions", function()
  local modified = { "one", "TWO", "THREE", "four", "six" }
  local bufnr = t:buffer(modified)
  hunk.set(bufnr, diff.run_diff({ "one", "two", "three", "four", "five", "six" }, modified))

  local regions ---@type table[]
  vim.api.nvim_buf_call(bufnr, function()
    regions = hunk.textobjects()
  end)
  hunk.remove(bufnr)

  t.assert_eq(2, #regions, "regions")
  t.assert_eq(1, regions[1][1], "first start")
  t.assert_eq(3, regions[1][3], "exclusive end row")
  t.assert_eq(0, regions[1][4], "exclusive byte column")
  t.assert_eq("V", regions[1].vis_mode, "linewise")
  t.assert_eq(3, regions[2][1], "second start")
end)

t:test("textobject: anchors a pure deletion to a selectable line", function()
  local bufnr = t:buffer({ "next" })
  hunk.set(bufnr, diff.run_diff({ "gone", "next" }, { "next" }))

  local regions ---@type table[]
  vim.api.nvim_buf_call(bufnr, function()
    regions = hunk.textobjects()
  end)
  hunk.remove(bufnr)

  t.assert_eq(0, regions[1][1], "top deletion anchor")
  t.assert_eq(1, regions[1][3], "exclusive anchor end")
  t.assert_eq("V", regions[1].vis_mode, "linewise")
end)

t:run()
