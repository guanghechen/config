/**
 * Checks if a URL is from localhost
 */
export function isLocalhost(url: string): boolean {
  try {
    const urlObj = new URL(url)
    return urlObj.hostname === 'localhost' || urlObj.hostname === '127.0.0.1'
  } catch (e) {
    return false
  }
}

/**
 * Checks if a URL is a yoz page (localhost with YOZ_SERVER_PORT)
 */
export function isYozUrl(url: string): boolean {
  try {
    const urlObj = new URL(url)
    return isLocalhost(url) && urlObj.port === __YOZ_SERVER_PORT__
  } catch (e) {
    return false
  }
}
