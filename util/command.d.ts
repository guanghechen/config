import type { Reporter } from '@guanghechen/stl/reporter'

export interface IExecParams {
  reporter: Reporter
  cmd: string
  args?: string[]
  cwd?: string
  env?: Record<string, string>
  timeout?: number
  silent?: boolean
}

export interface IExecResult {
  stdout: string
  stderr: string
  code: number
}

export function exec(params: IExecParams): Promise<IExecResult>
export function command_exists(reporter: Reporter, cmd: string): Promise<boolean>
