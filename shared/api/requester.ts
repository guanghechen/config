import { ApiRoutePathEnum } from '../constant/api'
import type { IRequestParams, IRequestPayload } from '../types/api'

// Global authentication interceptor for fetch requests
let onAuthenticationRequired: (() => void) | null = null

export function setAuthenticationRequiredHandler(handler: () => void): void {
  onAuthenticationRequired = handler
}

export interface IRequestOptions extends Omit<RequestInit, 'method' | 'body'> {
  credentials?: RequestCredentials
}

export class Requester {
  private isProtectedApiEndpoint(url: string): boolean {
    return (
      url.startsWith('/api/') &&
      !url.startsWith(ApiRoutePathEnum.USER_AUTH) &&
      !url.startsWith(ApiRoutePathEnum.USER_LOGOUT)
    )
  }

  private async fetch(
    method: string,
    url: string,
    params?: IRequestParams | IRequestPayload | BodyInit,
    options: IRequestOptions = {},
  ): Promise<Response> {
    const isProtected = this.isProtectedApiEndpoint(url)
    const defaultOptions: RequestInit = {
      method,
      credentials: isProtected ? 'include' : options.credentials || 'same-origin',
      ...options,
    }

    let finalUrl = url

    if (method === 'GET' || method === 'DELETE') {
      if (params && typeof params === 'object' && !(params instanceof FormData)) {
        const searchParams = new URLSearchParams()
        Object.entries(
          params as Record<string, string | number | boolean | null | undefined>,
        ).forEach(([key, value]) => {
          if (value != null) {
            searchParams.set(key, String(value))
          }
        })
        const queryString = searchParams.toString()
        finalUrl = queryString ? `${url}?${queryString}` : url
      }
    } else {
      if (params) {
        if (typeof params === 'string' || params instanceof FormData) {
          defaultOptions.body = params
        } else {
          defaultOptions.headers = {
            'Content-Type': 'application/json',
            ...defaultOptions.headers,
          }
          defaultOptions.body = JSON.stringify(params)
        }
      }
    }

    const response = await fetch(finalUrl, defaultOptions)

    // Handle 403 responses by triggering authentication for protected endpoints
    if (response.status === 403 && isProtected) {
      // Trigger authentication modal
      if (onAuthenticationRequired) {
        onAuthenticationRequired()
      }

      // Throw error to prevent infinite loops
      throw new Error('Authentication required')
    }

    return response
  }

  public async get(
    url: string,
    params?: IRequestParams,
    options?: IRequestOptions,
  ): Promise<Response> {
    return this.fetch('GET', url, params, options)
  }

  public async post(
    url: string,
    params?: IRequestPayload | BodyInit,
    options?: IRequestOptions,
  ): Promise<Response> {
    return this.fetch('POST', url, params, options)
  }

  public async patch(
    url: string,
    params?: IRequestPayload | BodyInit,
    options?: IRequestOptions,
  ): Promise<Response> {
    return this.fetch('PATCH', url, params, options)
  }

  public async put(
    url: string,
    params?: IRequestPayload | BodyInit,
    options?: IRequestOptions,
  ): Promise<Response> {
    return this.fetch('PUT', url, params, options)
  }

  public async delete(
    url: string,
    params?: IRequestParams,
    options?: IRequestOptions,
  ): Promise<Response> {
    return this.fetch('DELETE', url, params, options)
  }
}

export const requester = new Requester()
