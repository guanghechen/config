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
