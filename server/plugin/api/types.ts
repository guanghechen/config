import type { ServerResponse } from 'node:http'
import type { Connect } from 'vite'

export interface IApiHandleParams {
  readonly req: Connect.IncomingMessage
  readonly res: ServerResponse
  readonly next: Connect.NextFunction

  readonly pathname: string
  readonly search: string
  readonly searchParams: URLSearchParams
}

export type IApiHandle = (params: IApiHandleParams) => Promise<boolean>
