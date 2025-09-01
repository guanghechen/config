import { ApiRoutePathEnum } from '../../shared/constant/api'

// Global authentication interceptor for fetch requests
let onAuthenticationRequired: (() => void) | null = null

export function setAuthenticationRequiredHandler(handler: () => void): void {
  onAuthenticationRequired = handler
}

export async function authenticatedFetch(
  url: string,
  options: RequestInit = {},
): Promise<Response> {
  // No need to manually add Authorization header - cookies are sent automatically
  const response = await fetch(url, {
    ...options,
    credentials: 'include', // Ensure cookies are sent
  })

  // Handle 403 responses by triggering authentication
  if (response.status === 403) {
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
  return (
    url.startsWith('/api/') &&
    !url.startsWith(ApiRoutePathEnum.AUTH) &&
    !url.startsWith(ApiRoutePathEnum.LOGOUT)
  )
}
