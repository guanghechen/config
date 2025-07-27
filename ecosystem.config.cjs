const fs = require("node:fs");
const path = require("node:path");
const { command_exist } = require("./util.cjs");

const ROOT_CONFIG = path.resolve(__dirname, "..");
const ROOT_SOURCECODES = process.env.ROOT_SOURCECODES;

const GHC_COPILOT_API_HOST =
  String(process.env.GHC_COPILOT_API_HOST) || "127.0.0.1";
const GHC_COPILOT_API_PORT = Number.parseInt(
  String(process.env.GHC_COPILOT_API_PORT || 4343),
);

let LOCAL_TASKS = {};
const LOCAL_CONFIG_FILEPATH = path.normalize(
  path.resolve(__dirname, "local/tasks.cjs"),
);
if (fs.existsSync(LOCAL_CONFIG_FILEPATH)) {
  LOCAL_TASKS = require(LOCAL_CONFIG_FILEPATH);
}

const repos = {
  skhd: path.normalize(path.resolve(ROOT_CONFIG, "skhd")),
  yabai: path.normalize(path.resolve(ROOT_CONFIG, "yabai")),
  yozora: path.normalize(path.resolve(ROOT_CONFIG, "yozora")),
  copilot_api: path.normalize(
    path.resolve(ROOT_SOURCECODES, "github/ericc-ch/copilot-api"),
  ),
};

const config = {
  apps: [
    {
      enabled: fs.existsSync(repos.yozora),
      name: "yozora",
      cwd: repos.yozora,
      script: "npm",
      args: "run start",
      watch: true,
      env: {
        NODE_ENV: "development",
      },
    },
    {
      enabled: !!ROOT_SOURCECODES && fs.existsSync(repos.copilot_api),
      name: "copilot-api",
      cwd: path.normalize(
        path.resolve(ROOT_SOURCECODES, "github/ericc-ch/copilot-api"),
      ),
      script: "bun",
      args: `run start start --port=${GHC_COPILOT_API_PORT}`,
      env: {
        NODE_ENV: "production",
        HOST: GHC_COPILOT_API_HOST,
      },
    },
    {
      enabled: command_exist("yabai"),
      name: "yabai",
      cwd: repos.yabai,
      script: "yabai",
      args: "--start-service",
    },
    {
      enabled: command_exist("skhd"),
      name: "skhd",
      cwd: repos.skhd,
      script: "skhd",
      args: "--start-service",
    },
    ...(LOCAL_TASKS.apps || []),
  ].filter((x) => !!x && x.enabled),
};

module.exports = config;
