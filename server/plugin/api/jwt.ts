import jwt from 'jsonwebtoken'
import type { IApiHandleParams, IApiHandleResult } from './types'

const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-key'

interface IJwtPayload {
  readonly username: string
  readonly iat: number
  readonly exp: number
}

export function verifyJwtMiddleware(params: IApiHandleParams): IApiHandleResult | null {
  const { req } = params

  const authHeader = req.headers.authorization
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return {
      code: 403,
      data: {
        error: 'Missing or invalid authorization header',
        data: null,
      },
    }
  }

  const token = authHeader.slice(7) // Remove 'Bearer ' prefix

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as IJwtPayload
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
