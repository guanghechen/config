import { universalStorage } from './storage'

// Global authentication interceptor for fetch requests
let onAuthenticationRequired: (() => void) | null = null

export function setAuthenticationRequiredHandler(handler: () => void): void {
  onAuthenticationRequired = handler
}

async function getAuthToken(): Promise<string | null> {
  try {
    // Try to get token from auth storage first
    const authToken = await universalStorage.getAuthToken()
    if (authToken) {
      return authToken
    }

    // Fallback to context storage for backward compatibility
    const contextData = await universalStorage.getContext<{ token?: string }>('#/context/auth')
    return contextData?.token || null
  } catch (error) {
    console.warn('Failed to get auth token from storage:', error)
    return null
  }
}

export async function authenticatedFetch(
  url: string,
  options: RequestInit = {},
): Promise<Response> {
  const token = await getAuthToken()

  const headers = new Headers(options.headers)
  if (token) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  const response = await fetch(url, {
    ...options,
    headers,
  })

  // Handle 403 responses by triggering authentication
  if (response.status === 403) {
    try {
      // Clear invalid token from both auth and context storage
      await universalStorage.removeAuthToken()

      const contextData = await universalStorage.getContext<{
        token: string | null
        isAuthenticated?: boolean
      }>('#/context/auth')
      if (contextData) {
        contextData.token = null
        contextData.isAuthenticated = false
        await universalStorage.setContext('#/context/auth', contextData)
      }
    } catch (error) {
      console.warn('Failed to clear invalid auth token:', error)
    }

    // Trigger authentication modal
    if (onAuthenticationRequired) {
      onAuthenticationRequired()
    }

    // Throw error to prevent infinite loops
    throw new Error('Authentication required')
  }

  return response
}

// Helper function to check if a URL is an API endpoint that needs authentication
export function isProtectedApiEndpoint(url: string): boolean {
  return url.startsWith('/api/') && !url.startsWith('/api/auth')
}
