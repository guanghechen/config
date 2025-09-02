import { State, ViewModel } from '@guanghechen/viewmodel'
import { userController } from '@/shared/api'
import type { ILoginCredentials } from './types'

export class AuthViewModel extends ViewModel {
  public readonly loading$: State<boolean>
  public readonly error$: State<string | null>
  public readonly signed$: State<boolean>

  private authenticationDebounceTimer: NodeJS.Timeout | null = null

  constructor() {
    super()

    this.loading$ = new State<boolean>(false)
    this.error$ = new State<string | null>(null)
    this.signed$ = new State<boolean>(false)
  }

  public async login(credentials: ILoginCredentials): Promise<void> {
    this.loading$.next(true)
    this.error$.next(null)

    try {
      await userController.login(credentials)
      this.signed$.next(false) // Hide login popup

      // Refresh page to retrigger API calls with new authentication
      window.location.reload()
    } catch (error) {
      this.error$.next(error instanceof Error ? error.message : 'Authentication failed')
    } finally {
      this.loading$.next(false)
    }
  }

  public async logout(): Promise<void> {
    try {
      await userController.logout()
    } catch (error) {
      console.warn('Failed to logout on server:', error)
    }

    this.error$.next(null)
    this.signed$.next(false)

    // Refresh page to clear any cached authenticated state
    window.location.reload()
  }

  public async checkAuthenticationStatus(): Promise<void> {
    // Don't catch errors here - let 403 errors propagate to trigger authentication modal
    await userController.profile()
  }

  public clearError(): void {
    this.error$.next(null)
  }

  public requestAuthentication(): void {
    // Clear any existing debounce timer
    if (this.authenticationDebounceTimer) {
      clearTimeout(this.authenticationDebounceTimer)
    }

    // Only show popup if not already signing
    if (!this.signed$.getSnapshot()) {
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
