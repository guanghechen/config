export interface IAuthRequest {
  readonly authToken?: string
}

export interface IAuthResponse {
  readonly success: boolean
  readonly token: string
  readonly expiresIn?: string
  readonly message?: string
}

export interface IAuthState {
  readonly isAuthenticated: boolean
  readonly token: string | null
  readonly loading: boolean
  readonly error: string | null
}

export interface ILoginCredentials {
  readonly authToken?: string
}

export interface IAuthContextData {
  readonly isAuthenticated: boolean
  readonly token: string | null
  readonly loading: boolean
  readonly error: string | null
  readonly login: (credentials: ILoginCredentials) => Promise<void>
  readonly logout: () => void
  readonly clearError: () => void
}
