import { ApiRoutePathEnum } from '../constant/api'
import type {
  IUserAuthRequestPayload,
  IUserAuthResponseResult,
  IUserProfileResponseResult,
} from '../types/api/user'
import { requester } from './requester'

export class UserController {
  public async auth(payload: IUserAuthRequestPayload = {}): Promise<IUserAuthResponseResult> {
    const response = await requester.post(ApiRoutePathEnum.USER_AUTH, payload)

    const result = await response.json()

    if (response.ok && result.data) {
      return result.data
    } else {
      throw new Error(result.error || 'Authentication failed')
    }
  }

  // Legacy method for backwards compatibility - delegates to auth()
  public async login(payload: { authToken: string }): Promise<IUserAuthResponseResult> {
    return this.auth({ authToken: payload.authToken })
  }

  // Legacy method for backwards compatibility - delegates to auth()
  public async generateToken(): Promise<IUserAuthResponseResult> {
    return this.auth({})
  }

  public async logout(): Promise<void> {
    await requester.post(ApiRoutePathEnum.USER_LOGOUT)
  }

  public async profile(): Promise<IUserProfileResponseResult> {
    const response = await requester.get(ApiRoutePathEnum.USER_PROFILE)

    if (response.ok) {
      const result = await response.json()
      return result.data || { isAuthenticated: false }
    } else {
      return { isAuthenticated: false }
    }
  }
}

export const userController = new UserController()
