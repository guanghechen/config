import React from 'react'
import type { IWorkspaceItem } from '@/types/api'

export async function getWorkspaces(): Promise<IWorkspaceItem[]> {
  const response = await fetch('/api/workspaces')
  const { error, details, data } = await response.json()
  if (error || details || !data) {
    console.error('Failed to fetch workspaces:', { error, details, data })
    return []
  }
  return data.workspaces
}

export const useGetWorkspaces = (
  tick: number,
): { loading: boolean; workspaces: IWorkspaceItem[] } => {
  const [loading, setLoading] = React.useState<boolean>(true)
  const [workspaces, setWorkspaces] = React.useState<IWorkspaceItem[]>([])
  React.useEffect(() => {
    let cancelled: boolean = false
    void handle()

    async function handle(): Promise<void> {
      setLoading(true)

      try {
        const ws: IWorkspaceItem[] = await getWorkspaces()
        if (!cancelled) setWorkspaces(ws)
      } finally {
        setLoading(false)
      }
    }

    return (): void => {
      cancelled = true
    }
  }, [tick])

  return { loading, workspaces }
}
