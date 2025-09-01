import { State, ViewModel } from '@guanghechen/viewmodel'
import { ApiRoutePathEnum } from '../../../shared/constant/api'
import type { ILoginCredentials } from './types'

interface IProps {
  readonly isAuthenticated?: boolean
}

export class AuthViewModel extends ViewModel {
  public readonly isAuthenticated$: State<boolean>
  public readonly loading$: State<boolean>
  public readonly error$: State<string | null>
  public readonly signed$: State<boolean>

  private authenticationDebounceTimer: NodeJS.Timeout | null = null

  constructor(props: IProps = {}) {
    super()

    const { isAuthenticated = false } = props

    this.isAuthenticated$ = new State<boolean>(isAuthenticated)
    this.loading$ = new State<boolean>(false)
    this.error$ = new State<string | null>(null)
    this.signed$ = new State<boolean>(false)
  }

  public async login(credentials: ILoginCredentials): Promise<void> {
    this.loading$.next(true)
    this.error$.next(null)

    try {
      const response = await fetch(ApiRoutePathEnum.AUTH, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(credentials),
        credentials: 'include', // Include cookies
      })

      const result = await response.json()

      if (response.ok && result.data) {
        this.isAuthenticated$.next(true)
        this.signed$.next(false) // Hide login popup

        // Refresh page to retrigger API calls with new authentication
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

  public async logout(): Promise<void> {
    try {
      await fetch(ApiRoutePathEnum.LOGOUT, {
        method: 'POST',
        credentials: 'include', // Include cookies for logout
      })
    } catch (error) {
      console.warn('Failed to logout on server:', error)
    }

    this.isAuthenticated$.next(false)
    this.error$.next(null)
    this.signed$.next(false)

    // Refresh page to clear any cached authenticated state
    window.location.reload()
  }

  public async checkAuthenticationStatus(): Promise<void> {
    try {
      const response = await fetch(ApiRoutePathEnum.ME, {
        method: 'GET',
        credentials: 'include', // Include cookies
      })

      if (response.ok) {
        const result = await response.json()
        this.isAuthenticated$.next(result.data?.isAuthenticated || false)
      } else {
        this.isAuthenticated$.next(false)
      }
    } catch (error) {
      console.warn('Failed to check authentication status:', error)
      this.isAuthenticated$.next(false)
    }
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
