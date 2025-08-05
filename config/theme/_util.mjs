import { spawn } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { XDG_CONFIG_HOME } from "../_shared/env.mjs";
import { HOME_THEME_SCHEME, HOME_THEME_APP, cwd, themes } from "./_env.mjs";

/**
 * @param {string}                            theme
 * @param {string|undefined|null}             variant
 * @return {string}
 */
export function gen_full_theme_name(theme, variant) {
  return variant ? `${theme}-${variant}` : theme;
}

/**
 * @param {string}                            template
 * @param {import('./_env.mjs').IThemeScheme} scheme
 * @return {Promise<string>}
 */
export async function render_template(template, scheme) {
  const theme = scheme.theme;
  const variant = scheme.variant;
  const opposite = scheme.opposite;
  const darken = scheme.darken;
  const catppuccin = scheme.palette.catppuccin;
  const gruvbox = scheme.palette.gruvbox;
  const nord = scheme.palette.nord;
  const onehalf = scheme.palette.onehalf;
  const rosepine = scheme.palette.rosepine;
  const unified = scheme.palette.unified;
  const palette = Object.fromEntries(
    Object.entries({ catppuccin, gruvbox, nord, onehalf, rosepine }).filter(
      ([_, v]) => !!v,
    ),
  );

  const content = template.replace(/\{{2}([^\n]+?)\}{2}/g, (_, key) => {
    const fn = new Function(
      "theme",
      "variant",
      "opposite",
      "darken",
      "unified",
      "palette",
      "expression",
      `try { return (${key}) || expression; } catch { return \`{{\${expression}}}\`; }`,
    );
    const result = fn(theme, variant, opposite, darken, unified, palette);
    return result;
  });
  return content;
}

export async function safe_exec(cmd, args, extendedEnv) {
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
          cwd,
          env: { ...process.env, ...extendedEnv },
          stdio: ["ignore", "pipe", "pipe"], // Suppress output
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

/**
 * @param {string}                      theme
 * @return {Promise<import('./_env.mjs').IThemeScheme|undefined>}
 */
export async function load_theme_scheme(theme) {
  const filepath = path.join(HOME_THEME_SCHEME, `${theme}.json`);
  if (!existsSync(filepath)) {
    console.error("[load_theme_scheme] unknown theme.", { theme });
    return;
  }
  const content = await fs.readFile(filepath, "utf8");
  try {
    const scheme = JSON.parse(content);

    let data = {};
    for (const key of Object.keys(scheme.palette)) {
      if (key !== "unified") {
        data = { ...data, ...scheme.palette[key] };
      }
    }
    const resolvedContent = content.replaceAll(
      /\{{2}([\w]+)\}{2}/g,
      (_, key) => data[key] || `{{${key}}}`,
    );
    return JSON.parse(resolvedContent);
  } catch (error) {
    console.error("[load_theme_scheme] Bad scheme, not a valid json.", {
      theme,
      filepath,
      content,
    });
    return;
  }
}

/**
 * @param {IAppConfig}                  app
 * @param {import('./_env.mjs').IThemeScheme} scheme
 * @return {Promise<void>}
 */
export async function apply_theme_per_app(app, scheme) {
  if (!app.active(app)) return;
  if (app.local) {
    const template_filepath = path.join(HOME_THEME_APP, `${app.name}.hbs`);
    if (!existsSync(template_filepath)) {
      console.error("[gen_theme] Cannot find the template.", { app });
      return;
    }
    const template = await fs.readFile(template_filepath, "utf8");
    const content = await app.render(app, template, scheme);

    const theme_filepath = path.resolve(XDG_CONFIG_HOME, app.name, app.local);
    mkdirSync(path.dirname(theme_filepath), { recursive: true });
    await fs.writeFile(theme_filepath, content, "utf8");
  }

  await app.after_apply?.(app, scheme);
}

/**
 * @param {IAppConfig}  app
 * @return {Promise<void>}
 */
export async function gen_themes_per_app(app) {
  if (!app.active(app) || !app.themes) return;

  const template_filepath = path.join(HOME_THEME_APP, `${app.name}.hbs`);
  if (!existsSync(template_filepath)) {
    console.error("[gen_theme] Cannot find the template.", { app });
    return;
  }
  const template = await fs.readFile(template_filepath, "utf8");

  const THEME_HOME = path.join(XDG_CONFIG_HOME, app.name, app.themes);
  const tasks_gen_theme = themes.map((theme) => gen_theme(theme));
  await Promise.allSettled(tasks_gen_theme);

  /**
   * @param {string}      theme
   * @return {Promise<void>}
   */
  async function gen_theme(theme) {
    /** @type {import('./_env.mjs').IThemeScheme|undefined} */
    const scheme = await load_theme_scheme(theme);
    if (!scheme) return;

    const content = await app.render(app, template, scheme);
    const theme_filepath = path.resolve(THEME_HOME, `${theme}${app.extname}`);
    mkdirSync(path.dirname(theme_filepath), { recursive: true });
    await fs.writeFile(theme_filepath, content, "utf8");
  }
}
