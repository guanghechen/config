import path from 'node:path'

export const resolveRealFilepath = (filepath: string): string => {
  const p: string = filepath
    .replace(/^([a-zA-Z]):([\s\S]*)$/, (_, m1, m2) => `/mnt/${m1.toLowerCase()}/${m2}`)
    .replace(/[/\\]+/g, '/')
    .replace(/^~/, process.env.HOME || '')
  return path.normalize(p).replace(/[/\\]+/g, '/')
}
