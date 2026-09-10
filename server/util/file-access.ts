import { realpathSync, statSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'

export class FileAccessError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message)
    this.name = 'FileAccessError'
  }
}

export function containsPath(root: string, filepath: string): boolean {
  const relative = path.relative(root, filepath)
  return (
    relative === '' ||
    (!path.isAbsolute(relative) && relative !== '..' && !relative.startsWith(`..${path.sep}`))
  )
}

// Configuration may use ~; requests must already contain absolute filesystem paths.
export function resolveRoot(root: string): string {
  const expanded =
    root === '~'
      ? os.homedir()
      : root.startsWith('~/')
        ? path.join(os.homedir(), root.slice(2))
        : root
  if (!path.isAbsolute(expanded)) throw new Error('Filesystem roots must be absolute paths')
  const resolved = realpathSync(expanded)
  if (!statSync(resolved).isDirectory()) throw new Error('Filesystem roots must be directories')
  return resolved
}

export class FileAccess {
  public readonly allowedRoots: readonly string[]

  constructor(roots: readonly string[]) {
    this.allowedRoots = [...new Set(roots.map(resolveRoot))]
  }

  public resolve(filepath: unknown, kind?: 'file' | 'directory'): string {
    if (typeof filepath !== 'string' || !path.isAbsolute(filepath) || filepath.includes('\0')) {
      throw new FileAccessError('An absolute filesystem path is required', 400)
    }
    const normalized = path.normalize(filepath)
    if (!this.allowedRoots.some(root => containsPath(root, normalized))) {
      throw new FileAccessError('Path is outside allowed roots', 403)
    }
    try {
      const resolved = realpathSync(normalized)
      if (!this.allowedRoots.some(root => containsPath(root, resolved))) {
        throw new FileAccessError('Path is outside allowed roots', 403)
      }
      const stat = statSync(resolved)
      if ((kind === 'file' && !stat.isFile()) || (kind === 'directory' && !stat.isDirectory())) {
        throw new FileAccessError(`Expected a ${kind}`, 400)
      }
      return resolved
    } catch (error) {
      if (error instanceof FileAccessError) throw error
      const code = (error as NodeJS.ErrnoException).code
      if (code === 'ENOENT' || code === 'ENOTDIR') throw new FileAccessError('Path not found', 404)
      if (code === 'EACCES' || code === 'EPERM' || code === 'ELOOP')
        throw new FileAccessError('Path is inaccessible', 403)
      throw error
    }
  }
}

export interface IRootConfiguration {
  readonly access: FileAccess
  readonly defaultWorkspaceRoots: readonly string[]
  readonly legacyWorkspaces: ReadonlyArray<{ tag: string; path: string }>
}

export function configureRoots(
  env: Record<string, string | undefined>,
  demoRoot: string,
): IRootConfiguration {
  const legacy = [
    { tag: 'default', path: demoRoot },
    ...Object.entries(env)
      .filter(
        ([key, value]) =>
          key.startsWith('YOZ_WORKSPACE_') && key !== 'YOZ_WORKSPACE_DEFAULT' && !!value,
      )
      .map(([key, value]) => ({
        tag: key.slice('YOZ_WORKSPACE_'.length).toLowerCase(),
        path: value!,
      })),
  ]
  function parseRoots(key: string): string[] | undefined {
    if (env[key] === undefined) return undefined
    const value: unknown = JSON.parse(env[key]!)
    if (!Array.isArray(value) || !value.every(item => typeof item === 'string')) {
      throw new Error(`${key} must be a JSON array of absolute paths`)
    }
    return value
  }
  const allowed = parseRoots('YOZ_ALLOWED_ROOTS')
  const access = new FileAccess(allowed ?? legacy.map(item => item.path))
  const legacyWorkspaces = legacy.flatMap(item => {
    try {
      return [{ tag: item.tag, path: access.resolve(resolveRoot(item.path), 'directory') }]
    } catch (error) {
      // Legacy bookmarks never grant access when an explicit whitelist is configured.
      if (allowed !== undefined) return []
      throw error
    }
  })
  const defaults = parseRoots('YOZ_DEFAULT_WORKSPACE_ROOTS')
  const defaultWorkspaceRoots = [
    ...new Set(
      (defaults ?? access.allowedRoots).map(root => access.resolve(resolveRoot(root), 'directory')),
    ),
  ]
  return { access, defaultWorkspaceRoots, legacyWorkspaces }
}
