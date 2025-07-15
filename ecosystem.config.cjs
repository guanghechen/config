const path = require("node:path");

const ROOT_CONFIG = path.resolve(__dirname, "..");
const ROOT_SOURCECODES = process.env.ROOT_SOURCECODES;
const USERHOME = path.dirname(ROOT_CONFIG);

const COPILOT_API_PORT = Number.parseInt(
  String(process.env.COPILOT_API_PORT || 4343),
);

module.exports = {
  apps: [
    {
      name: "yozora",
      cwd: path.normalize(path.resolve(ROOT_CONFIG, "yozora")),
      script: "npm",
      args: "run start",
      watch: true,
      env: {
        NODE_ENV: "development",
      },
    },
    !!ROOT_SOURCECODES && {
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
  ].filter(Boolean),
};
