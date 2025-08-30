import { State, ViewModel } from '@guanghechen/viewmodel'
import type { ILoginCredentials } from './types'

export interface IAuthData {
  readonly token: string | null
  readonly isAuthenticated: boolean
}

interface IProps {
  readonly token?: string | null
  readonly isAuthenticated?: boolean
}

const DEFAULT_DATA: IAuthData = {
  token: null,
  isAuthenticated: false,
}

export class AuthViewModel extends ViewModel {
  public readonly isAuthenticated$: State<boolean>
  public readonly token$: State<string | null>
  public readonly loading$: State<boolean>
  public readonly error$: State<string | null>
  public readonly signed$: State<boolean>

  private authenticationDebounceTimer: NodeJS.Timeout | null = null

  public static fromData(data: Partial<IAuthData> | undefined): AuthViewModel {
    const normalizedData: IAuthData = this.normalize(DEFAULT_DATA, data)
    return new AuthViewModel(normalizedData)
  }

  public static normalize(base: IAuthData, data: Partial<IAuthData> | undefined): IAuthData {
    const { token = base.token, isAuthenticated = base.isAuthenticated } =
      data && typeof data === 'object' ? data : {}
    return { token: token ?? null, isAuthenticated: Boolean(token) || Boolean(isAuthenticated) }
  }

  constructor(props: IProps = {}) {
    super()

    const { token = null, isAuthenticated = false } = props

    this.isAuthenticated$ = new State<boolean>(Boolean(token) || isAuthenticated)
    this.token$ = new State<string | null>(token)
    this.loading$ = new State<boolean>(false)
    this.error$ = new State<string | null>(null)
    this.signed$ = new State<boolean>(false)
  }

  public dump = (): IAuthData => {
    const token: string | null = this.token$.getSnapshot()
    const isAuthenticated: boolean = this.isAuthenticated$.getSnapshot()
    return { token, isAuthenticated }
  }

  public load = (data: Partial<IAuthData> | undefined): void => {
    const { token, isAuthenticated }: IAuthData = AuthViewModel.normalize(this.dump(), data)
    this.token$.next(token)
    this.isAuthenticated$.next(isAuthenticated)
  }

  public async login(credentials: ILoginCredentials): Promise<void> {
    this.loading$.next(true)
    this.error$.next(null)

    try {
      const response = await fetch('/api/auth', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(credentials),
      })

      const result = await response.json()

      if (response.ok && result.data) {
        const { token } = result.data
        this.token$.next(token)
        this.isAuthenticated$.next(true)
        this.signed$.next(false) // Hide login popup

        // Refresh page to retrigger API calls with new token
        window.location.reload()
      } else {
        this.error$.next(result.error || 'Authentication failed')
      }
    } catch (error) {
      this.error$.next(error instanceof Error ? error.message : 'Network error')
    } finally {
      this.loading$.next(false)
    }
  }

  public logout(): void {
    this.isAuthenticated$.next(false)
    this.token$.next(null)
    this.error$.next(null)
    this.signed$.next(false)
  }

  public clearError(): void {
    this.error$.next(null)
  }

  public requestAuthentication(): void {
    // Clear any existing debounce timer
    if (this.authenticationDebounceTimer) {
      clearTimeout(this.authenticationDebounceTimer)
    }

    // Only show popup if not already authenticated and not already signing
    if (!this.isAuthenticated$.getSnapshot() && !this.signed$.getSnapshot()) {
      // Debounce with 300ms delay
      this.authenticationDebounceTimer = setTimeout(() => {
        this.signed$.next(true)
      }, 300)
    }
  }

  public closeAuthenticationDialog(): void {
    this.signed$.next(false)
    this.clearError()
  }
}
