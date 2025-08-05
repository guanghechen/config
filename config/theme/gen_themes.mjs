import { apps } from "./_config.mjs";
import { gen_themes_per_app } from "./_util.mjs";

const tasks = apps.map((app) => gen_themes_per_app(app));
const errors = await Promise.allSettled(tasks).then((results) =>
  results
    .filter((result) => result.status === "rejected")
    .map((result) => result.reason || result.message || result.stack || result),
);

if (errors.length > 0) {
  console.error("[gen_themes] Errors encountered:", errors);
}
