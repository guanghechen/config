import type { IApiHandle, IApiHandleData } from '../../../types'

interface IMeResponse {
  readonly isAuthenticated: boolean
}

export const getUserProfile: IApiHandle = async _params => {
  const responseData: IMeResponse = {
    isAuthenticated: true,
  }

  const data: IApiHandleData = {
    data: responseData,
  }

  return { code: 200, data }
}
