import React from 'react'
import { userController } from '@/shared/api'
import type { IAuthResponse, ILoginCredentials } from '@/shared/types/auth'

export interface IAuthResult {
  readonly loading: boolean
  readonly data?: IAuthResponse
  readonly error?: string
}

export const useAuth = (): {
  result: IAuthResult
  login: (credentials: ILoginCredentials) => Promise<IAuthResult>
} => {
  const [result, setResult] = React.useState<IAuthResult>({ loading: false })

  const login = React.useCallback(async (credentials: ILoginCredentials): Promise<IAuthResult> => {
    setResult({ loading: true })

    try {
      const data = await userController.login(credentials)
      const authResult: IAuthResult = { loading: false, data }
      setResult(authResult)
      return authResult
    } catch (error) {
      const authResult: IAuthResult = {
        loading: false,
        error: error instanceof Error ? error.message : 'Network error',
      }
      setResult(authResult)
      return authResult
    }
  }, [])

  return {
    result,
    login,
  }
}
