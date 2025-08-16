import React from 'react'
import type { ITransformConfig } from '@/shared/transformer'

export interface ITransformerSaveData {
  name: string
  split: string
  functions: Array<{
    type: 'filter' | 'map'
    code: string
    skip: boolean
  }>
  uuidFunction: string
  parentUuidFunction: string
}

export interface ITransformerSaveResult {
  loading: boolean
  error?: string
  save: (name: string, config: ITransformConfig) => Promise<void>
}

export async function postTransformer(name: string, config: ITransformConfig): Promise<void> {
  const saveData: ITransformerSaveData = {
    name: name.trim(),
    split: config.split,
    functions: config.transformers.map(transformer => ({
      type: transformer.type,
      code: transformer.function,
      skip: transformer.skipped || false,
    })),
    uuidFunction: config.uuidFunction,
    parentUuidFunction: config.parentUuidFunction,
  }

  const response = await fetch(`/api/transformer/text/${encodeURIComponent(name.trim())}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(saveData),
  })

  const result = await response.json()

  if (!response.ok) {
    throw new Error(result.error || 'Failed to save transformer')
  }
}

export const usePostTransformer = (): ITransformerSaveResult => {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | undefined>()

  const save = React.useCallback(async (name: string, config: ITransformConfig): Promise<void> => {
    if (!name.trim()) {
      throw new Error('Please enter a name for the transformer')
    }

    setLoading(true)
    setError(undefined)

    try {
      await postTransformer(name, config)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to save transformer'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [])

  return { loading, error, save }
}
