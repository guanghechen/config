import { useEffect, useRef, useState } from 'react'
import type { AgentGrantKind, IAgentControlStatus } from '@/agent/contract'
import type { IActivePageStatus } from '../service/active-page'
import {
  pairAgentBridge,
  readAgentBridgeStatus,
  unpairAgentBridge,
  writeAgentOriginGrant,
} from '../service/agent-bridge'

const EMPTY_STATUS: IAgentControlStatus = {
  paired: false,
  connected: false,
  grants: [],
  memoryGrants: [],
  actionGrants: [],
}

export interface IAgentBridgeViewModel {
  readonly currentOrigin: string | null
  readonly errorMessage: string | null
  readonly isBusy: boolean
  readonly isActionGranted: boolean
  readonly isMemoryGranted: boolean
  readonly isReadGranted: boolean
  readonly pairingCode: string
  readonly status: IAgentControlStatus
  readonly pair: () => void
  readonly setGrant: (grant: AgentGrantKind, allowed: boolean) => void
  readonly setPairingCode: (value: string) => void
  readonly unpair: () => void
}

export function useAgentBridge(pageStatus: IActivePageStatus | null): IAgentBridgeViewModel {
  const [status, setStatus] = useState<IAgentControlStatus>(EMPTY_STATUS)
  const [pairingCode, setPairingCode] = useState('')
  const [isBusy, setIsBusy] = useState(true)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const busyRef = useRef(false)
  const currentOrigin = resolveOrigin(pageStatus?.url)

  useEffect(() => {
    let active = true
    void readAgentBridgeStatus()
      .then(value => {
        if (active) setStatus(value)
      })
      .catch(cause => {
        if (active) setErrorMessage(readErrorMessage(cause))
      })
      .finally(() => {
        if (active) setIsBusy(false)
      })
    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    if (!status.paired) return undefined

    let active = true
    const intervalId = window.setInterval(() => {
      void readAgentBridgeStatus()
        .then(value => {
          if (active) setStatus(value)
        })
        .catch(() => undefined)
    }, 1_000)
    return () => {
      active = false
      window.clearInterval(intervalId)
    }
  }, [status.connected, status.paired])

  function pair(): void {
    void run(async () => {
      const nextStatus = await pairAgentBridge(pairingCode)
      setStatus(nextStatus)
      setPairingCode('')
    })
  }

  function unpair(): void {
    void run(async () => {
      setStatus(await unpairAgentBridge())
      setPairingCode('')
    })
  }

  function setGrant(grant: AgentGrantKind, allowed: boolean): void {
    if (!currentOrigin) return
    void run(async () => {
      setStatus(await writeAgentOriginGrant(currentOrigin, grant, allowed))
    })
  }

  async function run(action: () => Promise<void>): Promise<void> {
    if (busyRef.current) return
    busyRef.current = true
    setIsBusy(true)
    setErrorMessage(null)
    try {
      await action()
    } catch (cause) {
      setErrorMessage(readErrorMessage(cause))
    } finally {
      busyRef.current = false
      setIsBusy(false)
    }
  }

  return {
    currentOrigin,
    errorMessage,
    isBusy,
    isActionGranted: currentOrigin ? status.actionGrants.includes(currentOrigin) : false,
    isMemoryGranted: currentOrigin ? status.memoryGrants.includes(currentOrigin) : false,
    isReadGranted: currentOrigin ? status.grants.includes(currentOrigin) : false,
    pairingCode,
    status,
    pair,
    setGrant,
    setPairingCode,
    unpair,
  }
}

function resolveOrigin(url: string | undefined): string | null {
  if (!url) return null
  try {
    return new URL(url).origin
  } catch {
    return null
  }
}

function readErrorMessage(cause: unknown): string {
  return cause instanceof Error ? cause.message : 'Agent bridge request failed.'
}
