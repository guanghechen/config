import React from 'react'
import { authenticatedFetch, isProtectedApiEndpoint } from '@/util/auth'

export interface IDefaultCodeResult {
  readonly loading?: boolean
  readonly content?: string
  readonly error?: string
}

export async function getDefaultCode(filetype: string): Promise<IDefaultCodeResult> {
  if (!filetype) return { error: 'Filetype is required' }

  try {
    const url = `/api/config/code-default/${filetype}`
    const response = isProtectedApiEndpoint(url) ? await authenticatedFetch(url) : await fetch(url)

    if (!response.ok) {
      if (response.status === 404) {
        return { error: 'Default template not found for this file type' }
      }
      const errorData = await response.json().catch(() => null)
      return {
        error:
          errorData?.error ||
          `Failed to fetch default code: ${response.status} ${response.statusText}`,
      }
    }

    const content = await response.text()
    return { content }
  } catch (error) {
    console.error('Failed to fetch default code:', { filetype, error })

    // Handle authentication errors gracefully
    if (error instanceof Error && error.message === 'Authentication required') {
      return { error: 'Authentication required' }
    }

    return { error: `Failed to fetch default code: ${error}` }
  }
}

export const useGetDefaultCode = (filetype: string | null): IDefaultCodeResult => {
  const [result, setResult] = React.useState<IDefaultCodeResult>({})

  React.useEffect(() => {
    let cancelled = false

    async function handleFetch(): Promise<void> {
      if (!filetype) {
        setResult({})
        return
      }

      setResult({ loading: true })

      try {
        const fetchResult = await getDefaultCode(filetype)
        if (!cancelled) {
          setResult(fetchResult)
        }
      } catch (error) {
        if (!cancelled) {
          setResult({ error: `Failed to fetch default code: ${error}` })
        }
      }
    }

    void handleFetch()

    return (): void => {
      cancelled = true
    }
  }, [filetype])

  return result
}
