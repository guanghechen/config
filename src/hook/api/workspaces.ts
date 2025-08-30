import React from 'react'
import type { IWorkspaceItem } from '@/shared/types'
import { authenticatedFetch, isProtectedApiEndpoint } from '@/util/auth'

export async function getWorkspaces(): Promise<IWorkspaceItem[]> {
  const url = '/api/workspaces'
  const response = isProtectedApiEndpoint(url) ? await authenticatedFetch(url) : await fetch(url)
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
        const workspaces: IWorkspaceItem[] = await getWorkspaces()
        if (!cancelled) setWorkspaces(workspaces)
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
