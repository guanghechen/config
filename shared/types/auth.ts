export interface IAuthRequest {
  readonly username: string
  readonly password: string
}

export interface IAuthResponse {
  readonly token: string
  readonly expiresIn: string
}

export interface IAuthState {
  readonly isAuthenticated: boolean
  readonly token: string | null
  readonly username: string | null
  readonly loading: boolean
  readonly error: string | null
}

export interface ILoginCredentials {
  readonly username: string
  readonly password: string
}

export interface IAuthContextData {
  readonly isAuthenticated: boolean
  readonly token: string | null
  readonly username: string | null
  readonly loading: boolean
  readonly error: string | null
  readonly login: (credentials: ILoginCredentials) => Promise<void>
  readonly logout: () => void
  readonly clearError: () => void
}
