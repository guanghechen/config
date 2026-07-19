import {
  isAgentGrantKind,
  type IAgentControlRequest,
  type IAgentControlResponse,
} from '@/agent/contract'
import { AgentBridge } from './bridge'
import { PageRegistry } from './page-registry'

type BridgeStartupResult =
  { readonly ok: true; readonly stop: () => void } | { readonly ok: false; readonly error: unknown }

const CONTROL_ACTIONS = new Set(['status', 'pair', 'unpair', 'setGrant'])

export function startAgentBackground(): () => void {
  const registry = new PageRegistry()
  const stopRegistry = registry.start()
  const bridge = new AgentBridge(registry)
  const bridgeReady: Promise<BridgeStartupResult> = bridge.start().then(
    stop => ({ ok: true, stop }),
    error => ({ ok: false, error }),
  )
  let controlQueue = Promise.resolve<unknown>(undefined)

  const handleMessage = (
    message: unknown,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: IAgentControlResponse) => void,
  ): boolean | undefined => {
    if (!isControlRequest(message) || !isExtensionPageSender(_sender)) return undefined

    const response = controlQueue.then(async () => {
      const result = await bridgeReady
      if (!result.ok) throw result.error
      return handleControlRequest(bridge, message)
    })
    controlQueue = response.then(
      () => undefined,
      () => undefined,
    )

    void response
      .then(status => sendResponse({ ok: true, status }))
      .catch(cause => {
        sendResponse({
          ok: false,
          error: {
            code: 'INVALID_REQUEST',
            message: cause instanceof Error ? cause.message : 'Agent control request failed.',
          },
        })
      })
    return true
  }

  chrome.runtime.onMessage.addListener(handleMessage)
  return () => {
    chrome.runtime.onMessage.removeListener(handleMessage)
    void bridgeReady.then(result => {
      if (result.ok) result.stop()
    })
    stopRegistry()
  }
}

async function handleControlRequest(bridge: AgentBridge, request: IAgentControlRequest) {
  switch (request.action) {
    case 'status':
      return bridge.getStatus()
    case 'pair':
      if (!request.pairingCode) throw new Error('Pairing code is required.')
      return bridge.pair(request.pairingCode)
    case 'unpair':
      return bridge.unpair()
    case 'setGrant':
      if (
        !request.origin ||
        typeof request.allowed !== 'boolean' ||
        (request.grant !== undefined && !isAgentGrantKind(request.grant))
      ) {
        throw new Error('Origin and allowed are required.')
      }
      return bridge.setGrant(request.origin, request.grant ?? 'read', request.allowed)
  }
}

function isControlRequest(value: unknown): value is IAgentControlRequest {
  if (!value || typeof value !== 'object') return false
  const request = value as Partial<IAgentControlRequest>
  return (
    request.type === 'agent.control' &&
    typeof request.action === 'string' &&
    CONTROL_ACTIONS.has(request.action)
  )
}

function isExtensionPageSender(sender: chrome.runtime.MessageSender): boolean {
  if (sender.id !== chrome.runtime.id) return false
  return sender.url?.startsWith(`chrome-extension://${chrome.runtime.id}/`) ?? false
}
