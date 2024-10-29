import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import {
  __dirname,
  HOME_THEME_SCHEME,
  HOME_THEME_APP,
  HOME_CONFIG,
  apps,
} from "./config.mjs";

export async function touch(filepath) {
  if (fs.existsSync(filepath)) {
    try {
      const now = new Date();
      fs.utimesSync(filepath, now, now);
    } catch (error) {
      console.error("[touch] Error touching file:", { filepath, error });
    }
  }
}

export async function safe_exec(cmd, args) {
  const encoding = "utf8";

  try {
    const stdout = await new Promise((resolve, reject) => {
      let stdoutData = "";
      let stderrData = "";
      let terminated = false;

      const onResolved = () => {
        if (!terminated) {
          terminated = true;
          resolve(stdoutData.trimEnd());
        }
      };

      const onRejected = (error) => {
        if (!terminated) {
          terminated = true;
          reject(error || new Error((stderrData || stdoutData).trimEnd()));
        }
      };

      try {
        const child = spawn(cmd, args, {
          cwd: __dirname,
          env: process.env,
          stdio: "inherit",
        });
        child.stdout?.on("data", (data) => {
          stdoutData += data.toString(encoding);
        });
        child.stderr?.on("data", (data) => {
          stderrData += data.toString(encoding);
        });
        child.on("close", (code) => {
          if (code === 0) onResolved();
          else onRejected();
        });
      } catch (error) {
        onRejected(error);
      }
    });

    return { stdout };
  } catch (error) {
    console.error(`['safe_exec'] Failed to run command.`, { cmd, args, error });
  }
}

export async function gen_theme(app, theme) {
  const meta = apps[app];
  const template_filepath = path.join(
    HOME_THEME_APP,
    `${meta.template ?? app}.hbs`,
  );
  if (!fs.existsSync(template_filepath)) {
    console.error("[gen_theme] Cannot find the template.", { app, theme });
    return;
  }

  const template = fs.readFileSync(template_filepath, "utf8");
  const scheme_filepath = path.join(HOME_THEME_SCHEME, `${theme}.json`);
  if (!fs.existsSync(scheme_filepath)) {
    console.error("[gen_theme] Cannot find the scheme.", { app, theme });
    return;
  }

  const raw_scheme = fs.readFileSync(scheme_filepath, "utf8");
  const scheme = JSON.parse(raw_scheme);
  const mode = scheme.mode;
  const c = scheme.palette;

  const data = {
    black: mode === "light" ? c.fg0 : c.bg0,
    white: mode === "light" ? c.bg4 : c.fg4,
    brightBlack: mode === "light" ? c.fg1 : c.bg1,
    brightWhite: mode === "light" ? c.bg1 : c.fg1,
    ...c,
    mode,
    theme: scheme.theme,
  };
  const content = template.replace(
    /\{{2}([\w]+)\}{2}/g,
    (_, key) => data[key] || `{{${key}}}`,
  );
  return content;
}

export async function gen_and_save_theme(app, theme) {
  if (!HOME_CONFIG) return;

  const meta = apps[app];
  const app_home = path.join(HOME_CONFIG, app);
  if (!fs.existsSync(app_home)) return;
  if (!fs.statSync(app_home).isDirectory()) return;

  const content = gen_theme(app, theme);
  if (!content) return;

  const theme_filepath = path.join(
    app_home,
    path.normalize(meta.scheme_home ?? "theme"),
    `${theme}${meta.extname}`,
  );
  fs.mkdirSync(path.dirname(theme_filepath), { recursive: true });
  fs.writeFileSync(theme_filepath, content, "utf8");
}

export async function toggle_theme(app, theme) {
  if (!HOME_CONFIG) return;
  if (app === "nvim" || app === "nvim-nvchad") return;

  const meta = apps[app];
  const app_home = path.join(HOME_CONFIG, app);
  if (!fs.existsSync(app_home)) return;
  if (!fs.statSync(app_home).isDirectory()) return;

  const theme_filepath = path.join(
    app_home,
    path.normalize(meta.scheme_home ?? "theme"),
    `${theme}${meta.extname}`,
  );
  if (!fs.existsSync(theme_filepath)) await gen_and_save_theme(app, theme);

  const local_theme_filepath = path.join(
    app_home,
    "local",
    `theme${meta.extname}`,
  );
  fs.mkdirSync(path.dirname(local_theme_filepath), { recursive: true });
  fs.copyFileSync(theme_filepath, local_theme_filepath);

  const main_config_filepath = path.resolve(
    app_home,
    path.normalize(meta.main ?? ""),
  );

  switch (app) {
    case "alacritty": {
      const main_config_filepath = path.join(app_home, "alacritty.toml");
      await touch(main_config_filepath);
      break;
    }
    case "fish":
      break;
    case "lazygit":
      break;
    case "tmux": {
      if (process.env.TMUX) {
        safe_exec("tmux", ["source-file", main_config_filepath]);
      }
      break;
    }
    default:
      break;
  }
}

export async function toggle_theme_windows_terminal(theme) {
  const main_config_filepath = apps.windows_terminal.main;
  if (
    main_config_filepath &&
    fs.existsSync(main_config_filepath) &&
    fs.statSync(main_config_filepath).isFile()
  ) {
    const raw_content = fs.readFileSync(main_config_filepath, "utf8");
    const settings = JSON.parse(raw_content);

    if (settings?.profiles?.defaults?.colorScheme) {
      settings.profiles.defaults.colorScheme = theme;
    }

    const raw_scheme = await gen_theme("windows_terminal", theme);
    const scheme = JSON.parse(raw_scheme);
    if (Array.isArray(settings.schemes)) {
      if (settings.schemes.some((s) => s.name === theme)) {
        settings.schemes = settings.schemes.map((s) =>
          s.name === theme ? scheme : s,
        );
      } else {
        settings.schemes.push(scheme);
      }
    } else {
      settings.schemes = [scheme];
    }
    const content = JSON.stringify(settings, null, 2);
    fs.writeFileSync(main_config_filepath, content, "utf8");
  }
}
