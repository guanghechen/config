import * as cookie from 'cookie'
import jwt from 'jsonwebtoken'
import type { IncomingHttpHeaders } from 'node:http'
import type { IApiHandleParams, IApiHandleResult } from './types'
const COOKIE_NAME = 'yoz-auth'

interface IJwtPayload {
  readonly authenticated: boolean
  readonly iat: number
  readonly exp: number
}

export function getAuthToken(headers: IncomingHttpHeaders): string | undefined {
  const authHeader = headers.authorization
  if (authHeader?.startsWith('Bearer ')) return authHeader.slice(7)
  return headers.cookie ? cookie.parseCookie(headers.cookie)[COOKIE_NAME] : undefined
}

export function verifyAuthToken(token: string): IJwtPayload {
  const secret = process.env.YOZ_JWT_SECRET
  if (!secret) throw new Error('JWT secret not configured')
  const decoded = jwt.verify(token, secret)
  if (
    typeof decoded === 'string' ||
    decoded.authenticated !== true ||
    typeof decoded.exp !== 'number'
  ) {
    throw new Error('Invalid authentication claims')
  }
  return decoded as IJwtPayload
}

export function verifyJwtMiddleware(params: IApiHandleParams): IApiHandleResult | null {
  const { req } = params
  const token = getAuthToken(req.headers)

  if (!token) {
    return {
      code: 401,
      data: {
        error: 'Missing or invalid authorization header',
        data: null,
      },
    }
  }

  try {
    const jwtSecret = process.env.YOZ_JWT_SECRET
    if (!jwtSecret) {
      return {
        code: 500,
        data: {
          error: 'JWT secret not configured',
          data: null,
        },
      }
    }

    const decoded = verifyAuthToken(token)
    // Add user info to request for potential use in handlers
    ;(req as any).user = decoded
    return null // Continue to handler
  } catch (error) {
    return {
      code: 401,
      data: {
        error: 'Invalid or expired token',
        details: error instanceof Error ? error.message : error,
        data: null,
      },
    }
  }
}
