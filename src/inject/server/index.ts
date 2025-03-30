import { TsukiEventResponseCodeEnum } from '@/shared/enum/event'
import type {
  ITsukiRequestContext,
  ITsukiRequestData,
  ITsukiResponseData,
} from '@/shared/types/event'
import { handleEvent } from './handle'

async function setup(): Promise<void> {
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    const data: ITsukiRequestData = message.data
    const context: ITsukiRequestContext = {
      sender,
      eventName: data.event,
      eventData: data.payload,
    }

    void handleEvent(context)
      .then(response => {
        sendResponse(response)
      })
      .catch(error => {
        const response: ITsukiResponseData = {
          code: TsukiEventResponseCodeEnum.SERVER_ERROR,
          error: {
            message: error?.message || error?.stack || String(error),
            details: { error },
          },
        }
        sendResponse(response)
      })
  })
}

void setup().catch(error => {
  console.error(error)
})
