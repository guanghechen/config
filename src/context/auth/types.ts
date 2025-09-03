export interface IAuthState {
  readonly isAuthenticated: boolean
  readonly token: string | null
  readonly loading: boolean
  readonly error: string | null
}

export interface ILoginCredentials {
  readonly authToken?: string
}
