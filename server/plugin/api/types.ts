import type { ServerResponse } from 'node:http'
import type { Connect } from 'vite'

export interface IApiHandleParams {
  readonly req: Connect.IncomingMessage
  readonly res: ServerResponse
  next: Connect.NextFunction

  readonly pathname: string
  readonly search: string
  readonly searchParams: URLSearchParams
  readonly body?: string
}

export interface IApiHandleData {
  readonly error?: string
  readonly details?: unknown
  readonly data: unknown
  readonly headers?: Record<string, string>
}

export interface IApiHandleResult {
  readonly code: number
  readonly data: IApiHandleData
}

export type IApiHandle = (params: IApiHandleParams) => Promise<IApiHandleResult | true>
