import React from 'react'

export async function getWorkspaceFiles(workspace: string | null): Promise<string[]> {
  if (!workspace) return []

  const ups = new URLSearchParams()
  ups.set('workspace', workspace)
  const search = '?' + ups.toString()

  const response = await fetch(`/api/workspace/files/${search}`)
  const { error, details, data } = await response.json()
  if (error || details || !data) {
    console.error('Failed to fetch workspaces:', { error, details, data })
    return []
  }
  return data.files
}

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
        const _files: string[] = await getWorkspaceFiles(workspace)
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
