export type IUserAuthRequestParams = Record<string, never>

export interface IUserAuthRequestPayload {
  readonly authToken?: string
}

export interface IUserAuthResponseResult {
  readonly success: boolean
  readonly token: string
  readonly expiresIn?: string
  readonly message?: string
}

export type IUserLogoutRequestParams = Record<string, never>

export type IUserLogoutRequestPayload = Record<string, never>

export type IUserLogoutResponseResult = Record<string, never>

export type IUserProfileRequestParams = Record<string, never>

export type IUserProfileRequestPayload = Record<string, never>

export interface IUserProfileResponseResult {
  readonly isAuthenticated: boolean
}
