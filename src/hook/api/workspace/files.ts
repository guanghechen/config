import React from 'react'
import { workspaceController } from '@/shared/api'
import type { IWorkspaceFiles } from '@/shared/types'

export const useGetWorkspaceFiles = (
  root: string | null,
  tick: number,
): { loading: boolean; root: string | null; files: string[]; error: string | null } => {
  const [loading, setLoading] = React.useState<boolean>(true)
  const [resolvedRequestRoot, setResolvedRequestRoot] = React.useState<string | null>(null)
  const [canonicalRoot, setCanonicalRoot] = React.useState<string | null>(null)
  const [files, setFiles] = React.useState<string[]>([])
  const [error, setError] = React.useState<string | null>(null)
  React.useEffect(() => {
    let cancelled: boolean = false
    void handle()

    async function handle(): Promise<void> {
      if (!root) {
        setResolvedRequestRoot(null)
        setCanonicalRoot(null)
        setFiles([])
        setError(null)
        setLoading(false)
        return
      }

      setLoading(true)
      setError(null)

      try {
        const result: IWorkspaceFiles = await workspaceController.files(root)
        if (!cancelled) {
          setResolvedRequestRoot(root)
          setCanonicalRoot(result.root)
          setFiles(result.files)
        }
      } catch (error) {
        if (!cancelled) {
          setResolvedRequestRoot(root)
          setCanonicalRoot(null)
          setFiles([])
          setError(error instanceof Error ? error.message : String(error))
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    return (): void => {
      cancelled = true
    }
  }, [root, tick])

  if (resolvedRequestRoot !== root) {
    return { loading: !!root, root: null, files: [], error: null }
  }
  return { loading, root: canonicalRoot, files, error }
}
