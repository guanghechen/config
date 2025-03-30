import type { TsukiEventNameEnum, TsukiEventResponseCodeEnum } from '../enum/event'

export interface ITsukiResponseError {
  readonly message: string
  readonly details: unknown
}

export interface ITsukiResponseData<D = unknown> {
  readonly code: TsukiEventResponseCodeEnum
  readonly data?: D | null
  readonly error?: ITsukiResponseError
}

export interface ITsukiRequestContext {
  readonly sender: chrome.runtime.MessageSender
  readonly eventName: TsukiEventNameEnum
  readonly eventData: unknown
}

export interface ITsukiRequestData {
  readonly event: TsukiEventNameEnum
  readonly payload: unknown
}
