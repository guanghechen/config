import { existsSync } from "node:fs";
import path from "node:path";

/**
 * @param {string} dirpath
 * @returns {string|null}
 */
function resolveGitRepoRootDir(dirpath) {
  let currentDir = path.resolve(dirpath);

  while (currentDir !== path.dirname(currentDir)) {
    const gitDir = path.join(currentDir, ".git");
    if (existsSync(gitDir)) {
      return currentDir;
    }
    currentDir = path.dirname(currentDir);
  }

  return null;
}

export const git = { resolveGitRepoRootDir };

