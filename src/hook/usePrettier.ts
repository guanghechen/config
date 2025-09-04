import React from 'react'
import { toast } from 'react-toastify'
import { type IPrettierFormatOptions, type IPrettierResult, formatCode } from '@/util/prettier'

interface IUsePrettierState {
  readonly isFormatting: boolean
  readonly lastResult: IPrettierResult | null
}

interface IUsePrettierReturn extends IUsePrettierState {
  readonly format: (
    code: string,
    language: string,
    options?: Partial<IPrettierFormatOptions>,
  ) => Promise<IPrettierResult>
  readonly formatWithNotifications: (
    code: string,
    language: string,
    options?: Partial<IPrettierFormatOptions>,
  ) => Promise<IPrettierResult>
  readonly clearResult: () => void
}

export const usePrettier = (): IUsePrettierReturn => {
  const [state, setState] = React.useState<IUsePrettierState>({
    isFormatting: false,
    lastResult: null,
  })

  const format = React.useCallback(
    async (
      code: string,
      language: string,
      options?: Partial<IPrettierFormatOptions>,
    ): Promise<IPrettierResult> => {
      setState(prev => ({ ...prev, isFormatting: true }))

      try {
        const result = await formatCode(code, language, options)
        setState(prev => ({ ...prev, isFormatting: false, lastResult: result }))
        return result
      } catch (error) {
        const errorResult: IPrettierResult = {
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        }
        setState(prev => ({ ...prev, isFormatting: false, lastResult: errorResult }))
        return errorResult
      }
    },
    [],
  )

  const formatWithNotifications = React.useCallback(
    async (
      code: string,
      language: string,
      options?: Partial<IPrettierFormatOptions>,
    ): Promise<IPrettierResult> => {
      setState(prev => ({ ...prev, isFormatting: true }))

      try {
        const result = await formatCode(code, language, options)
        setState(prev => ({ ...prev, isFormatting: false, lastResult: result }))

        if (result.success) {
          if (result.formatted && result.formatted !== code) {
            toast.success('Code formatted successfully')
          } else {
            toast.success('Code is already properly formatted')
          }
        } else {
          toast.error(result.error || 'Failed to format code')
        }

        return result
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        const errorResult: IPrettierResult = {
          success: false,
          error: errorMessage,
        }
        setState(prev => ({ ...prev, isFormatting: false, lastResult: errorResult }))
        toast.error(`Formatting failed: ${errorMessage}`)
        return errorResult
      }
    },
    [],
  )

  const clearResult = React.useCallback(() => {
    setState(prev => ({ ...prev, lastResult: null }))
  }, [])

  return {
    ...state,
    format,
    formatWithNotifications,
    clearResult,
  }
}
