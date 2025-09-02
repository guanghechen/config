import * as cookie from 'cookie'
import type { IApiHandle, IApiHandleData } from '../../../types'

const COOKIE_NAME = 'yoz-auth'

interface ILogoutResponse {
  readonly success: boolean
}

export const postUserLogout: IApiHandle = async () => {
  const responseData: ILogoutResponse = {
    success: true,
  }

  const cookieValue = cookie.serialize(COOKIE_NAME, '', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 0, // Expire immediately
    path: '/',
  })

  const data: IApiHandleData = {
    data: responseData,
    headers: {
      'Set-Cookie': cookieValue,
    },
  }

  return { code: 200, data }
}
