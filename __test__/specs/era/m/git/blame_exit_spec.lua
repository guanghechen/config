local harness = require("__test__.support.harness")
local t = harness.new("era.m.git.blame exit")

t:test("Neovim exit acknowledges cancellation of a blocked native blame process", function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
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
  local command = {
    vim.v.progpath,
    "--headless",
    "-u",
    "NONE",
    "-i",
    "NONE",
    "-n",
    "-l",
    repo .. "/__test__/fixtures/era/m/git/job_exit.lua",
    repo,
    root,
    marker,
    "blame",
  }
  local result = vim
    .system(command, {
      text = true,
      env = {
        PATH = root .. (windows and ";" or ":") .. (vim.env.PATH or ""),
        YOZ_TEST_BLAME_MARKER = marker,
      },
    })
    :wait(10000)
  t.assert_eq(0, result.code, result.stderr)
  t.assert_true(result.stdout:find("native-exit-acknowledged", 1, true) ~= nil, "worker acknowledged exit cleanup")
end)

t:run()
