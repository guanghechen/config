import type { IAgentPageAdapter } from '@/agent/contract'

export function createGenericAgentAdapter(website: string): IAgentPageAdapter {
  return {
    website,
    capabilities: [],
  }
}
