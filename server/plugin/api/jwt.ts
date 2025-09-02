import * as cookie from 'cookie'
import jwt from 'jsonwebtoken'
import { getJwtSecret } from '../../util/jwt-secret'
import type { IApiHandleParams, IApiHandleResult } from './types'
const COOKIE_NAME = 'yoz-auth'

interface IJwtPayload {
  readonly username: string
  readonly iat: number
  readonly exp: number
}

export function verifyJwtMiddleware(params: IApiHandleParams): IApiHandleResult | null {
  const { req } = params

  // Check for Bearer token in Authorization header first
  const authHeader = req.headers.authorization
  let token: string | undefined

  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7) // Remove 'Bearer ' prefix
  } else {
    // Fallback to cookie-based authentication
    const cookies = req.headers.cookie ? cookie.parse(req.headers.cookie) : {}
    token = cookies[COOKIE_NAME]
  }

  if (!token) {
    return {
      code: 403,
      data: {
        error: 'Missing or invalid authorization header',
        data: null,
      },
    }
  }

  try {
    const jwtSecret = getJwtSecret()
    const decoded = jwt.verify(token, jwtSecret) as IJwtPayload
    // Add user info to request for potential use in handlers
    ;(req as any).user = decoded
    return null // Continue to handler
  } catch (error) {
    return {
      code: 403,
      data: {
        error: 'Invalid or expired token',
        details: error instanceof Error ? error.message : error,
        data: null,
      },
    }
  }
}
