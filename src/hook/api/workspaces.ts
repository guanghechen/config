import React from 'react'
import { workspaceController } from '@/shared/api'
import type { IWorkspaceItem } from '@/shared/api'

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
        const workspaces: IWorkspaceItem[] = await workspaceController.list()
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
