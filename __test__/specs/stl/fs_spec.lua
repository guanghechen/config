local harness = require("__test__.support.harness")

local t = harness.new()

local Fs = require("stl.fs")

-- Writes exact bytes; `writefile` would end every line with LF.
---@param text                          string
---@return string
local function fixture(text)
  local filepath = vim.fs.joinpath(t:tempdir(), "lines.txt")
  local file = assert(io.open(filepath, "wb"))
  file:write(text)
  file:close()
  return filepath
end

t:test("read_file_as_lines: drops only the carriage return of a CRLF line break", function()
  local filepath = fixture("a\r\nb\nc\rd\r\n\r\n\26tail")
  t.assert_same({ "a", "b", "c\rd", "", "\26tail" }, Fs.read_file_as_lines({ filepath = filepath }), "lines")
end)

t:test("read_file_as_lines: stops at max_lines", function()
  local filepath = fixture("a\r\nb\r\nc\r\n")
  t.assert_same({ "a", "b" }, Fs.read_file_as_lines({ filepath = filepath, max_lines = 2 }), "lines")
end)

t:run()
