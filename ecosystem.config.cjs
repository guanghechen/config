const fs = require("node:fs");
const path = require("node:path");

const ROOT_CONFIG = path.resolve(__dirname, "..");
const ROOT_SOURCECODES = process.env.ROOT_SOURCECODES;

const COPILOT_API_PORT = Number.parseInt(
  String(process.env.COPILOT_API_PORT || 4343),
);

let LOCAL_TASKS = {};
const LOCAL_CONFIG_FILEPATH = path.normalize(
  path.resolve(__dirname, "local/tasks.cjs"),
);
if (fs.existsSync(LOCAL_CONFIG_FILEPATH)) {
  LOCAL_TASKS = require(LOCAL_CONFIG_FILEPATH);
}

const repos = {
  yozora: path.normalize(path.resolve(ROOT_CONFIG, "yozora")),
  copilot_api: path.normalize(
    path.resolve(ROOT_SOURCECODES, "github/ericc-ch/copilot-api"),
  ),
};

const config = {
  apps: [
    fs.existsSync(repos.yozora) && {
      name: "yozora",
      cwd: repos.yozora,
      script: "npm",
      args: "run start",
      watch: true,
      env: {
        NODE_ENV: "development",
      },
    },
    !!ROOT_SOURCECODES &&
      fs.existsSync(repos.copilot_api) && {
        name: "copilot-api",
        cwd: path.normalize(
          path.resolve(ROOT_SOURCECODES, "github/ericc-ch/copilot-api"),
        ),
        script: "bun",
        args: `run start start --port=${COPILOT_API_PORT}`,
        env: {
          NODE_ENV: "production",
          HOST: "127.0.0.1",
        },
      },
    ...(LOCAL_TASKS.apps || []),
  ].filter(Boolean),
};

module.exports = config;
