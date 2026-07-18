import type {
  IAgentControlRequest,
  IAgentControlResponse,
  IAgentControlStatus,
} from '@/agent/contract'

export async function readAgentBridgeStatus(): Promise<IAgentControlStatus> {
  return sendControlRequest({ type: 'agent.control', action: 'status' })
}

export async function pairAgentBridge(pairingCode: string): Promise<IAgentControlStatus> {
  return sendControlRequest({ type: 'agent.control', action: 'pair', pairingCode })
}

export async function unpairAgentBridge(): Promise<IAgentControlStatus> {
  return sendControlRequest({ type: 'agent.control', action: 'unpair' })
}

export async function writeAgentOriginGrant(
  origin: string,
  allowed: boolean,
): Promise<IAgentControlStatus> {
  return sendControlRequest({ type: 'agent.control', action: 'setGrant', origin, allowed })
}

async function sendControlRequest(request: IAgentControlRequest): Promise<IAgentControlStatus> {
  if (typeof chrome === 'undefined' || !chrome.runtime?.sendMessage) {
    throw new Error('Agent bridge is only available inside the extension.')
  }

  const response: unknown = await chrome.runtime.sendMessage(request)
  if (!isControlResponse(response)) throw new Error('Agent bridge returned an invalid response.')
  if (!response.ok || !response.status) {
    throw new Error(response.error?.message ?? 'Agent bridge request failed.')
  }
  return response.status
}

function isControlResponse(value: unknown): value is IAgentControlResponse {
  if (!value || typeof value !== 'object') return false
  const response = value as Partial<IAgentControlResponse>
  return typeof response.ok === 'boolean'
}
