/**
 * @typedef {import('#env').PLATFORM} IPlatform
 */

/**
 * @typedef {object} IMatch
 * @property {string} matched_text
 * @property {string[]} matched_groups
 * @property {number} offset_start
 * @property {number} offset_end
 */

/**
 * @typedef {object} IPatch
 * @property {string} name
 * @property {string} version
 * @property {IPlatform[]} platform
 * @property {string | RegExp} search
 * @property {(original: string, matches: IMatch[]) => string} replace
 * @property {(text: string) => boolean} verify
 */

/**
 * @typedef {object} IApplyOptions
 * @property {IPatch[]} patches
 * @property {boolean} [stopOnFirst]
 */

export {}
