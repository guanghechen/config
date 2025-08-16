import React from 'react'
import type { ITransformConfig } from '@/shared/transformer'

export interface ITransformerLoadResult {
  loading: boolean
  error?: string
  load: (name: string) => Promise<ITransformConfig>
}

export async function getTransformer(name: string): Promise<ITransformConfig> {
  const response = await fetch(`/api/transformer/text/${encodeURIComponent(name)}`)
  const result = await response.json()

  if (!response.ok || !result.data?.transformer) {
    throw new Error(result.error || 'Failed to load transformer')
  }

  const transformer = result.data.transformer

  return {
    name: transformer.name,
    split: transformer.split || '\n',
    uuidFunction: transformer.uuidFunction || '',
    parentUuidFunction: transformer.parentUuidFunction || '() => []',
    transformers: (transformer.functions || transformer.transformers || []).map(
      (func: any, index: number) => ({
        id: `loaded-${Date.now()}-${index}`,
        type: func.type || 'map',
        function: func.code || func.function || '',
        skipped: func.skip !== undefined ? func.skip : func.skipped || false,
      }),
    ),
  }
}

export const useGetTransformer = (): ITransformerLoadResult => {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | undefined>()

  const load = React.useCallback(async (name: string): Promise<ITransformConfig> => {
    setLoading(true)
    setError(undefined)

    try {
      const config = await getTransformer(name)
      return config
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load transformer'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [])

  return { loading, error, load }
}
