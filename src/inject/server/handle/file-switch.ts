import { TsukiEventResponseCodeEnum } from '@/shared/enum/event'
import type {
  IFileSwitchPayload,
  ITsukiRequestContext,
  ITsukiResponseData,
} from '@/shared/types/event'
import { isLocalhost, isYozUrl } from '@/shared/util/url'
import { reporter } from '../state'

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

  const payload = eventData as IFileSwitchPayload

  // If sender tab is active, send FILE_SWITCH directly
  if (sender.tab?.active) {
    return sendFileSwitchToTab(tabid, payload)
  }

  // Sender tab is not active, find the most recently accessed yoz tab
  const yozTabs = await queryYozTabs()
  if (yozTabs.length > 0) {
    // Sort by lastAccessed descending, pick the most recent one
    const targetTab = yozTabs.sort((a, b) => (b.lastAccessed ?? 0) - (a.lastAccessed ?? 0))[0]
    if (targetTab.id) {
      await focusTab(targetTab.id, targetTab.windowId)
      return sendFileSwitchToTab(targetTab.id, payload)
    }
  }

  // No yoz tabs, silently ignore
  return { code: TsukiEventResponseCodeEnum.SUCCEED }
}

async function queryYozTabs(): Promise<chrome.tabs.Tab[]> {
  return new Promise(resolve => {
    chrome.tabs.query({}, tabs => {
      const yozTabs = tabs.filter(tab => tab.url && isYozUrl(tab.url))
      resolve(yozTabs)
    })
  })
}

async function focusTab(tabId: number, windowId?: number): Promise<void> {
  return new Promise(resolve => {
    chrome.tabs.update(tabId, { active: true }, () => {
      if (windowId) {
        chrome.windows.update(windowId, { focused: true }, () => resolve())
      } else {
        resolve()
      }
    })
  })
}

function sendFileSwitchToTab(
  tabId: number,
  payload: IFileSwitchPayload,
): Promise<ITsukiResponseData> {
  return new Promise<ITsukiResponseData>(resolve => {
    chrome.tabs.sendMessage(tabId, { action: 'FILE_SWITCH', payload }, () => {
      if (chrome.runtime.lastError) {
        reporter.error(
          '[tsuki.server] Error sending file switch message:',
          chrome.runtime.lastError,
        )
        resolve({
          code: TsukiEventResponseCodeEnum.SERVER_ERROR,
          error: {
            message: chrome.runtime.lastError.message || 'failed to send file switch message',
            details: { tabId, payload },
          },
        })
        return
      }
      resolve({ code: TsukiEventResponseCodeEnum.SUCCEED })
    })
  })
}
