export function isLocalUrl(url: string | null | undefined): url is string {
  return !!url && (url[0] === '.' || url[0] === '/' || url[0] === '\\')
}
