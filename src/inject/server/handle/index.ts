import { TsukiEventNameEnum, TsukiEventResponseCodeEnum } from '@/shared/enum/event'
import type { ITsukiRequestContext, ITsukiResponseData } from '@/shared/types/event'
import { reporter } from '../state'
import { handleFocusMeEvent } from './focus-me'

export async function handleEvent(context: ITsukiRequestContext): Promise<ITsukiResponseData> {
  switch (context.eventName) {
    case TsukiEventNameEnum.FOCUS_ME:
      return handleFocusMeEvent(context)
    default: {
      reporter.warn('[tsuki.server] Unknown event:', context.eventName)
      const response: ITsukiResponseData = {
        code: TsukiEventResponseCodeEnum.BAD_REQUEST,
        error: {
          message: 'Unknown event',
          details: {
            eventName: context.eventName,
            eventData: context.eventData,
            tabid: context.sender.tab?.id,
            url: context.sender.url,
          },
        },
      }
      return response
    }
  }
}
