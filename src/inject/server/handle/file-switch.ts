import { TsukiEventResponseCodeEnum } from '@/shared/enum/event'
import type { ITsukiRequestContext, ITsukiResponseData } from '@/shared/types/event'
import { isLocalhost } from '@/shared/util/url'
import { reporter } from '../state'

interface IFileSwitchPayload {
  workspace: string | null
  filepath: string
}

export async function handleFileSwitchEvent(
  context: ITsukiRequestContext,
): Promise<ITsukiResponseData> {
  const { sender, eventData } = context

  const url = sender.url
  if (!url || !isLocalhost(url)) {
    reporter.warn('[tsuki.server] Rejected event from non-localhost source:', url)
    return {
      code: TsukiEventResponseCodeEnum.BAD_REQUEST,
      error: {
        message: 'Access denied: only localhost sources are allowed',
        details: { url },
      },
    }
  }

  const tabid = sender.tab?.id
  if (!tabid) {
    reporter.warn('[tsuki.server] Cannot switch file: no tab ID in sender')
    return {
      code: TsukiEventResponseCodeEnum.BAD_REQUEST,
      error: {
        message: 'No tab ID found',
        details: { tabid },
      },
    }
  }

  // Check if the sender tab is the active tab
  if (!sender.tab?.active) {
    // Silently ignore if not active tab
    reporter.debug('[tsuki.server] Ignore file switch event from inactive tab:', tabid)
    const response: ITsukiResponseData = {
      code: TsukiEventResponseCodeEnum.SUCCEED,
    }
    return response
  }

  // Send FILE_SWITCH message to the active tab
  const payload = eventData as IFileSwitchPayload
  return new Promise<ITsukiResponseData>(resolve => {
    chrome.tabs.sendMessage(tabid, { action: 'FILE_SWITCH', payload }, response => {
      if (chrome.runtime.lastError) {
        reporter.error(
          '[tsuki.server] Error sending file switch message:',
          chrome.runtime.lastError,
        )
        const errorResponse: ITsukiResponseData = {
          code: TsukiEventResponseCodeEnum.SERVER_ERROR,
          error: {
            message: chrome.runtime.lastError.message || 'failed to send file switch message',
            details: { tabid, payload },
          },
        }
        resolve(errorResponse)
        return
      }

      const successResponse: ITsukiResponseData = {
        code: TsukiEventResponseCodeEnum.SUCCEED,
      }
      resolve(successResponse)
    })
  })
}
