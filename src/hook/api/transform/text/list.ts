import React from 'react'

export interface ITransformerListItem {
  name: string
  lastModified?: string
}

export interface ITransformerListResult {
  loading: boolean
  transformers: ITransformerListItem[]
  error?: string
  refresh: () => Promise<void>
}

export async function getTransformerList(): Promise<ITransformerListItem[]> {
  const response = await fetch('/api/transform/text/list')
  const result = await response.json()

  if (response.ok && result.data?.transformers) {
    return result.data.transformers
  } else {
    throw new Error(result.error || 'Failed to load transformers')
  }
}

export const useGetTransformerList = (): ITransformerListResult => {
  const [loading, setLoading] = React.useState(false)
  const [transformers, setTransformers] = React.useState<ITransformerListItem[]>([])
  const [error, setError] = React.useState<string | undefined>()

  const refresh = React.useCallback(async (): Promise<void> => {
    setLoading(true)
    setError(undefined)

    try {
      const list = await getTransformerList()
      setTransformers(list)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch transformer list'
      setError(errorMessage)
      setTransformers([])
    } finally {
      setLoading(false)
    }
  }, [])

  return { loading, transformers, error, refresh }
}
