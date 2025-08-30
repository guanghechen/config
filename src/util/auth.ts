// Global authentication interceptor for fetch requests
let onAuthenticationRequired: (() => void) | null = null

export function setAuthenticationRequiredHandler(handler: () => void): void {
  onAuthenticationRequired = handler
}

function getAuthToken(): string | null {
  // Get token from context storage
  const contextData = JSON.parse(localStorage.getItem('#/context/auth') || '{}')
  return contextData.token || null
}

export async function authenticatedFetch(
  url: string,
  options: RequestInit = {},
): Promise<Response> {
  const token = getAuthToken()

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
    // Clear invalid token from context storage
    const contextData = JSON.parse(localStorage.getItem('#/context/auth') || '{}')
    contextData.token = null
    contextData.isAuthenticated = false
    localStorage.setItem('#/context/auth', JSON.stringify(contextData))

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
