import * as cookie from 'cookie'
import jwt from 'jsonwebtoken'
import crypto from 'node:crypto'
import type { IApiHandle, IApiHandleData } from '../../types'

const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-key'
const JWT_EXPIRES_IN = '7d'
const COOKIE_NAME = 'yoz-auth'
const COOKIE_MAX_AGE = 7 * 24 * 60 * 60 * 1000 // 7 days in milliseconds

interface IAuthRequest {
  readonly username: string
  readonly password: string
}

interface IAuthResponse {
  readonly success: boolean
  readonly token: string
  readonly expiresIn: string
}

function hashPassword(password: string): string {
  return crypto.createHash('sha1').update(password).digest('hex')
}

export const authenticateUser: IApiHandle = async params => {
  const { body } = params

  if (!body) {
    const data: IApiHandleData = {
      error: 'Request body is required',
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

  const { username, password } = authRequest

  if (!username || !password) {
    const data: IApiHandleData = {
      error: 'Username and password are required',
      data: null,
    }
    return { code: 400, data }
  }

  const expectedUsername = process.env.YOZ_USERNAME
  const expectedPassword = process.env.YOZ_PASSWORD

  if (!expectedUsername || !expectedPassword) {
    const data: IApiHandleData = {
      error: 'Authentication not configured',
      data: null,
    }
    return { code: 500, data }
  }

  const hashedPassword = hashPassword(password)

  if (username !== expectedUsername || hashedPassword !== expectedPassword) {
    const data: IApiHandleData = {
      error: 'Invalid credentials',
      data: null,
    }
    return { code: 403, data }
  }

  try {
    const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN })

    const responseData: IAuthResponse = {
      success: true,
      token,
      expiresIn: JWT_EXPIRES_IN,
    }

    const cookieValue = cookie.serialize(COOKIE_NAME, token, {
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
      error: 'Failed to generate token',
      details: _error,
      data: null,
    }
    return { code: 500, data }
  }
}
