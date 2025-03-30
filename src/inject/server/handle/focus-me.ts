import { TsukiEventResponseCodeEnum } from '@/shared/enum/event'
import type { ITsukiRequestContext, ITsukiResponseData } from '@/shared/types/event'
import { isLocalhost } from '@/shared/util/url'
import { reporter } from '../state'

export async function handleFocusMeEvent(
  context: ITsukiRequestContext,
): Promise<ITsukiResponseData> {
  const { sender } = context

  const url = sender.url
  if (!url || !isLocalhost(url)) {
    reporter.warn('[tsuki.server] Rejected event from non-localhost source:', url)
    return {
      code: TsukiEventResponseCodeEnum.BAD_REQUEST,
      error: {
        message: 'ccess denied: only localhost sources are allowed',
        details: { url },
      },
    }
  }

  const tabid = sender.tab?.id
  if (!tabid) {
    reporter.warn('[tsuki.server] Cannot focus tab: no tab ID in sender')
    return {
      code: TsukiEventResponseCodeEnum.BAD_REQUEST,
      error: {
        message: 'No tab ID found',
        details: { tabid },
      },
    }
  }

  if (sender.tab?.active) {
    const response: ITsukiResponseData = {
      code: TsukiEventResponseCodeEnum.SUCCEED,
    }
    return response
  }

  return new Promise<ITsukiResponseData>(resolve => {
    chrome.tabs.update(tabid, { active: true }, tab => {
      if (chrome.runtime.lastError) {
        reporter.error('[tsuki.server] Error focusing tab:', chrome.runtime.lastError)
        const response: ITsukiResponseData = {
          code: TsukiEventResponseCodeEnum.SERVER_ERROR,
          error: {
            message: chrome.runtime.lastError.message || 'failed to focusing tab',
            details: { tabid },
          },
        }
        resolve(response)
        return
      }

      // Also bring the window to the front
      if (tab?.windowId) {
        chrome.windows.update(tab.windowId, { focused: true }, () => {
          const response: ITsukiResponseData = {
            code: TsukiEventResponseCodeEnum.SUCCEED,
          }
          resolve(response)
        })
        return
      }

      const response: ITsukiResponseData = {
        code: TsukiEventResponseCodeEnum.SUCCEED,
      }
      resolve(response)
      return
    })
  })
}
