import { createGenericAgentAdapter } from '@/agent/adapter/generic'
import { startAgentPage } from '@/agent/content/runtime'
import type { TsukiEventNameEnum } from '@/shared/enum/event'
import { TsukiTargetEnum } from '@/shared/enum/event'
import type { ITsukiRequestData } from '@/shared/types/event'

const VALID_TARGETS = new Set<string>(Object.values(TsukiTargetEnum))

// Listen to messages from the page
window.addEventListener('message', event => {
  if (event.source !== window || !event.data) return

  const action: string = event.data.action
  if (!VALID_TARGETS.has(action)) return

  const payload = event.data['tsuki']
  if (!payload) return

  const name: string = '@tsuki/' + payload.event.replace(/^@tsuki\//, '')
  const data: ITsukiRequestData = {
    event: name as TsukiEventNameEnum,
    payload: payload.payload,
    target: action as TsukiTargetEnum,
  }
  void chrome.runtime.sendMessage({ data })
})

// Listen to messages from chrome.runtime and forward to the page
chrome.runtime.onMessage.addListener((message, _sender, _sendResponse) => {
  if (message.action === 'FILE_SWITCH') {
    window.postMessage(
      {
        action: 'FILE_SWITCH',
        payload: message.payload,
      },
      window.location.origin,
    )
  }
})

const stopAgentPage = startAgentPage(createGenericAgentAdapter('yoz'))

window.addEventListener('pagehide', stopAgentPage, { once: true })
