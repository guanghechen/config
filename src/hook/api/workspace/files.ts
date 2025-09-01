import React from 'react'
import { workspaceController } from '@/shared/api'

export const useGetWorkspaceFiles = (
  workspace: string | null,
  tick: number,
): { loading: boolean; files: string[] } => {
  const [loading, setLoading] = React.useState<boolean>(true)
  const [files, setFiles] = React.useState<string[]>([])
  React.useEffect(() => {
    let cancelled: boolean = false
    void handle()

    async function handle(): Promise<void> {
      setLoading(true)

      try {
        const _files: string[] = await workspaceController.files(workspace)
        if (!cancelled) setFiles(_files)
      } finally {
        setLoading(false)
      }
    }

    return (): void => {
      cancelled = true
    }
  }, [workspace, tick])

  return { loading, files }
}
