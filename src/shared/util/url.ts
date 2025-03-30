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
