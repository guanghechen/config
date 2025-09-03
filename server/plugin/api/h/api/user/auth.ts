import * as cookie from 'cookie'
import jwt from 'jsonwebtoken'
import state from '../../../../../state'
import type { IApiHandle, IApiHandleData } from '../../../types'

const JWT_EXPIRES_IN = '7d'
const COOKIE_NAME = 'yoz-auth'
const COOKIE_MAX_AGE = 7 * 24 * 60 * 60 * 1000 // 7 days in milliseconds

interface IAuthRequest {
  readonly authToken: string
}

interface IAuthResponse {
  readonly success: boolean
  readonly token: string
  readonly expiresIn: string
}

export const postUserAuth: IApiHandle = async params => {
  const { body } = params

  if (!body) {
    const data: IApiHandleData = {
      error: 'Auth token is required',
      data: null,
    }
    return { code: 400, data }
  }

  let authRequest: IAuthRequest
  try {
    authRequest = JSON.parse(body) as IAuthRequest
  } catch (_authError) {
    const data: IApiHandleData = {
      error: 'Invalid JSON in request body',
      data: null,
    }
    return { code: 400, data }
  }

  const { authToken } = authRequest

  if (!authToken) {
    const data: IApiHandleData = {
      error: 'Auth token is required',
      data: null,
    }
    return { code: 400, data }
  }

  const expectedToken = process.env.YOZ_AUTH_TOKEN

  if (!expectedToken) {
    const data: IApiHandleData = {
      error: 'Authentication not configured',
      data: null,
    }
    return { code: 500, data }
  }

  if (authToken !== expectedToken) {
    const data: IApiHandleData = {
      error: 'Invalid authentication token',
      data: null,
    }
    state.reporter.warn('Failed authentication attempt with invalid token')
    return { code: 403, data }
  }

  try {
    const jwtSecret = process.env.YOZ_JWT_SECRET
    if (!jwtSecret) {
      const data: IApiHandleData = {
        error: 'JWT secret not configured',
        data: null,
      }
      return { code: 500, data }
    }

    const jwtToken = jwt.sign({ authenticated: true }, jwtSecret, { expiresIn: JWT_EXPIRES_IN })

    const responseData: IAuthResponse = {
      success: true,
      token: jwtToken,
      expiresIn: JWT_EXPIRES_IN,
    }

    const cookieValue = cookie.serialize(COOKIE_NAME, jwtToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: COOKIE_MAX_AGE,
      path: '/',
    })

    const data: IApiHandleData = {
      data: responseData,
      headers: {
        'Set-Cookie': cookieValue,
      },
    }

    return { code: 200, data }
  } catch (_error) {
    const data: IApiHandleData = {
      error: 'Failed to generate JWT token',
      details: _error,
      data: null,
    }
    return { code: 500, data }
  }
}
