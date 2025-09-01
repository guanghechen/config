import React from 'react'
import { ApiRoutePathEnum } from '@/shared/constant/api'
import { authenticatedFetch } from '@/util/auth'

export interface IFileSaveParams {
  workspace: string | null
  filepath: string
  content: string
}

export interface IFileSaveResult {
  loading: boolean
  error?: string
  save: (params: IFileSaveParams) => Promise<void>
}

export async function postFile(params: IFileSaveParams): Promise<void> {
  const { workspace, filepath, content } = params

  const response = await authenticatedFetch(ApiRoutePathEnum.FILE_SAVE, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      workspace,
      filepath,
      content,
    }),
  })

  if (!response.ok) {
    throw new Error(`Failed to save: ${response.status} ${response.statusText}`)
  }
}

export const usePostFile = (): IFileSaveResult => {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | undefined>()

  const save = React.useCallback(async (params: IFileSaveParams): Promise<void> => {
    setLoading(true)
    setError(undefined)

    try {
      await postFile(params)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [])

  return { loading, error, save }
}
