import { startAgentBackground } from '@/agent/background'
import { TsukiEventResponseCodeEnum } from '@/shared/enum/event'
import type {
  ITsukiRequestContext,
  ITsukiRequestData,
  ITsukiResponseData,
} from '@/shared/types/event'
import { handleEvent } from './handle'

function setup(): void {
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (!isTsukiRequestMessage(message)) return undefined

    const data = message.data
    const context: ITsukiRequestContext = {
      sender,
      eventName: data.event,
      eventData: data.payload,
      target: data.target,
    }

    void handleEvent(context)
      .then(response => sendResponse(response))
      .catch(error => {
        const response: ITsukiResponseData = {
          code: TsukiEventResponseCodeEnum.SERVER_ERROR,
          error: {
            message: error instanceof Error ? error.message : String(error),
            details: null,
          },
        }
        sendResponse(response)
      })

    return true
  })

  try {
    startAgentBackground()
  } catch {
    // The optional agent bridge must not prevent core background events from starting.
  }
}

function isTsukiRequestMessage(value: unknown): value is { readonly data: ITsukiRequestData } {
  if (!value || typeof value !== 'object') return false
  const data = (value as { data?: unknown }).data
  if (!data || typeof data !== 'object') return false
  const request = data as Partial<ITsukiRequestData>
  return typeof request.event === 'string' && typeof request.target === 'string'
}

setup()
