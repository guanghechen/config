import { ApiRoutePathEnum } from '../constant/api'
import type {
  IUserLoginRequestPayload,
  IUserLoginResponseResult,
  IUserProfileResponseResult,
} from '../types/api/user'
import { requester } from './requester'

export class UserController {
  public async login(payload: IUserLoginRequestPayload): Promise<IUserLoginResponseResult> {
    const response = await requester.post(ApiRoutePathEnum.USER_LOGIN, payload)

    const result = await response.json()

    if (response.ok && result.data) {
      return result.data
    } else {
      throw new Error(result.error || 'Authentication failed')
    }
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
