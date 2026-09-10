import * as cookie from 'cookie'
import state from '../../../../../state'
import { getAuthToken } from '../../../jwt'
import type { IApiHandle, IApiHandleData } from '../../../types'

const COOKIE_NAME = 'yoz-auth'

interface ILogoutResponse {
  readonly success: boolean
}

export const postUserLogout: IApiHandle = async ({ req }) => {
  const token = getAuthToken(req.headers)
  if (token) state.authLogout$.next(token)
  const responseData: ILogoutResponse = {
    success: true,
  }

  const cookieValue = cookie.stringifySetCookie({
    name: COOKIE_NAME,
    value: '',
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
