import type { IApiHandle, IApiHandleData } from '../../types'

interface IMeResponse {
  readonly isAuthenticated: boolean
  readonly username?: string
}

export const getCurrentUser: IApiHandle = async params => {
  const { req } = params

  const user = (req as any).user

  const responseData: IMeResponse = {
    isAuthenticated: true,
    username: user?.username,
  }

  const data: IApiHandleData = {
    data: responseData,
  }

  return { code: 200, data }
}
