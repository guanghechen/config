const path = require("node:path");

const ROOT_CONFIG = path.resolve(__dirname, "..");
const ROOT_SOURCECODES = process.env.ROOT_SOURCECODES;
const USERHOME = path.dirname(ROOT_CONFIG);

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
      args: "run start start --port=4343",
      env: {
        NODE_ENV: "production",
        HOST: "127.0.0.1",
      },
    },
  ].filter(Boolean),
};
