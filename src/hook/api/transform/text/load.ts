import React from 'react'
import type { ITextTransformConfig } from '@/shared/types'
import { TextTransformStepTypeEnum } from '@/shared/types'

export interface ITransformerLoadResult {
  loading: boolean
  error?: string
  load: (name: string) => Promise<ITextTransformConfig>
}

export async function getTransformer(name: string): Promise<ITextTransformConfig> {
  const response = await fetch(`/api/transform/text/${encodeURIComponent(name)}`)
  const result = await response.json()

  if (!response.ok || !result.data?.transformer) {
    throw new Error(result.error || 'Failed to load transformer')
  }

  const transformer = result.data.transformer

  return {
    name: transformer.name,
    split: transformer.split || '\n',
    uuid: transformer.uuid || '',
    parents: transformer.parents || '() => []',
    steps: (transformer.steps || []).map((step: any, index: number) => ({
      id: `loaded-${Date.now()}-${index}`,
      type: step.type || TextTransformStepTypeEnum.MAP,
      code: step.code || '',
      skip: step.skip ?? false,
    })),
  }
}

export const useGetTransformer = (): ITransformerLoadResult => {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | undefined>()

  const load = React.useCallback(async (name: string): Promise<ITextTransformConfig> => {
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
