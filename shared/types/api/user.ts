export type IUserLoginRequestParams = Record<string, never>

export interface IUserLoginRequestPayload {
  readonly username: string
  readonly password: string
}

export interface IUserLoginResponseResult {
  readonly isAuthenticated: boolean
  readonly username?: string
  readonly token: string
  readonly expiresIn: string
}

export type IUserLogoutRequestParams = Record<string, never>

export type IUserLogoutRequestPayload = Record<string, never>

export type IUserLogoutResponseResult = Record<string, never>

export type IUserProfileRequestParams = Record<string, never>

export type IUserProfileRequestPayload = Record<string, never>

export interface IUserProfileResponseResult {
  readonly isAuthenticated: boolean
  readonly username?: string
}
