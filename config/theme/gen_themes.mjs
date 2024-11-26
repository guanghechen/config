import { apps } from "./_config.mjs";
import { gen_themes_per_app } from "./_util.mjs";

const tasks = apps.map((app) => gen_themes_per_app(app));
await Promise.allSettled(tasks);
