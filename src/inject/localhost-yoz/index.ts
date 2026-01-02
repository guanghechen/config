import type { TsukiEventNameEnum } from '@/shared/enum/event'
import { TsukiTargetEnum } from '@/shared/enum/event'
import type { ITsukiRequestData } from '@/shared/types/event'

const VALID_TARGETS = new Set<string>(Object.values(TsukiTargetEnum))

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
