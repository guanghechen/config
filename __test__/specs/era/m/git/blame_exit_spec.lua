local harness = require("__test__.support.harness")
local process = require("__test__.support.process")
local t = harness.new()

t:test("Neovim exit acknowledges cancellation of a blocked native blame process", function()
  if vim.fn.executable("rustc") ~= 1 then
    t.skip("needs rustc to build the controlled Git process")
  end
  local root = t:tempdir()
  local marker = root .. "/started"
  local repo = assert(vim.uv.cwd())
  local windows = package.config:sub(1, 1) == "\\"
  local executable = root .. (windows and "/git.exe" or "/git")
  local build = vim
    .system({ "rustc", "--edition", "2024", "-", "-o", executable }, {
      text = true,
      stdin = [[
fn main() {
    let marker = std::env::var_os("YOZ_TEST_BLAME_MARKER").expect("marker path");
    std::fs::write(marker, b"started\n").expect("write marker");
    std::thread::sleep(std::time::Duration::from_secs(30));
}
]],
    })
    :wait(15000)
  t.assert_eq(0, build.code, build.stderr)
  local result = process.script(t, "__test__/fixtures/era/m/git/job_exit.lua", { repo, root, marker, "blame" }, {
    PATH = root .. (windows and ";" or ":") .. (vim.env.PATH or ""),
    YOZ_TEST_BLAME_MARKER = marker,
  })
  t.assert_eq(0, result.code, result.stderr)
  t.assert_true(result.stdout:find("native-exit-acknowledged", 1, true) ~= nil, "worker acknowledged exit cleanup")
end)

t:run()
