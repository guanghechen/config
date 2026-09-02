import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { describe, it } from 'node:test'

const powershellHelperPath = path.join(import.meta.dirname, '../setup/win/bot/step.ps1')
const powershellSetupPath = path.join(import.meta.dirname, '../setup/win/setup.ps1')
const wingetScriptPath = path.join(import.meta.dirname, '../setup/win/winget.ps1')
const ansiPattern = /\u001B\[[0-9;]*m/g
const hasPowerShell = spawnSync(
  'pwsh',
  ['-NoProfile', '-NonInteractive', '-Command', 'exit 0'],
).status === 0

function normalizeOutput(value) {
  return value.replaceAll('\r\n', '\n').trim()
}

function runPowerShellStepScript(body) {
  const script = [
    `. ${JSON.stringify(powershellHelperPath)}`,
    body,
  ].join('\n')
  const result = spawnSync(
    'pwsh',
    [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      Buffer.from(script, 'utf16le').toString('base64'),
    ],
    { encoding: 'utf8' },
  )
  return {
    status: result.status,
    rawOutput: normalizeOutput(result.stdout),
    output: normalizeOutput(result.stdout.replaceAll(ansiPattern, '')),
  }
}

describe('windows setup step forest', { skip: !hasPowerShell }, () => {
  it('renders flat sections containing independent rounded trees', () => {
    const result = runPowerShellStepScript(String.raw`
      Start-GhcSection '' demo
      Invoke-GhcStep '󰒓' alpha {
        Write-Host 'line one' -ForegroundColor Magenta
        Write-Output ([string]::Concat([char]10, 'line two', [char]10, 'stale', [char]13, 'current'))
      }
      Skip-GhcStep '' beta 'not applicable'
      Complete-GhcSetup
    `)

    assert.equal(result.status, 0)
    assert.equal(result.output, [
      ' demo',
      '╭─ 󰒓 alpha',
      '│  line one',
      '│  line two',
      '│  current',
      '╰─ ✓ done',
      '',
      '╭─  beta',
      '╰─ ○ skipped — not applicable',
      '',
      ' summary',
      '╭─ 󰒓 setup',
      '╰─ ✓ all sections completed',
    ].join('\n'))
    assert.doesNotMatch(result.output, /[├└]/)
    assert.doesNotMatch(result.output, /●/)
    assert.doesNotMatch(result.output, /stale/)

    const railLines = result.rawOutput
      .split('\n')
      .filter(line => /[╭│╰]/.test(line.replaceAll(ansiPattern, '')))
    for (const line of railLines) assert.match(line, /^\u001B\[90m[╭│╰]/)
    assert.ok(result.rawOutput.includes(
      '\u001B[90m│\u001B[0m  \u001B[95mline one\u001B[0m',
    ))
    assert.ok(result.rawOutput.includes(
      '\u001B[90m╭─\u001B[0m \u001B[96m󰒓 alpha\u001B[0m',
    ))
  })

  it('collects optional failures with their section path', () => {
    const result = runPowerShellStepScript(String.raw`
      $hostPath = (Get-Process -Id $PID).Path
      Start-GhcSection '' environment
      Invoke-GhcStep '' node {
        Write-Host diagnostic
        & $hostPath -NoProfile -NonInteractive -Command 'exit 7'
      } -Optional
      Invoke-GhcStep '' theme {
        & $hostPath -NoProfile -NonInteractive -Command 'exit 8'
      } -Optional
      Complete-GhcSetup
    `)

    assert.equal(result.status, 1)
    assert.match(result.output, /^ environment/)
    assert.match(result.output, /╭─  node/)
    assert.match(result.output, /│  diagnostic/)
    assert.match(result.output, /╰─ ✗ failed \(exit 7\); continuing/)
    assert.match(result.output, /╭─  theme/)
    assert.match(result.output, /╰─ ✗ failed \(exit 8\); continuing/)
    assert.match(result.output, /│  environment \/ node/)
    assert.match(result.output, /│  environment \/ theme/)
    assert.match(result.output, /╰─ ✗ completed with 2 failed steps$/)
  })

  it('treats non-terminating PowerShell errors as failures', () => {
    const result = runPowerShellStepScript(String.raw`
      Start-GhcSection '' environment
      Invoke-GhcStep '' config {
        Write-Error diagnostic
      } -Optional
      Complete-GhcSetup
    `)

    assert.equal(result.status, 1)
    assert.match(result.output, /│  diagnostic/)
    assert.match(result.output, /╰─ ✗ failed \(exit 1\); continuing/)
    assert.doesNotMatch(result.output, /✓ all sections completed/)
  })

  it('stops at the first failed native command', () => {
    const result = runPowerShellStepScript(String.raw`
      $hostPath = (Get-Process -Id $PID).Path
      Start-GhcSection '' environment
      Invoke-GhcStep '' native {
        & $hostPath -NoProfile -NonInteractive -Command 'exit 7'
        & $hostPath -NoProfile -NonInteractive -Command 'exit 0'
      } -Optional
      Complete-GhcSetup
    `)

    assert.equal(result.status, 1)
    assert.match(result.output, /╰─ ✗ failed \(exit 7\); continuing/)
    assert.doesNotMatch(result.output, /✓ all sections completed/)
  })

  it('continues when winget reports no applicable upgrade', () => {
    const result = runPowerShellStepScript(String.raw`
      $global:GhcWingetCalls = [System.Collections.Generic.List[string]]::new()
      $installer = {
        param([string]$Package)
        [void]$global:GhcWingetCalls.Add($Package)
        if ($global:GhcWingetCalls.Count -eq 1) {
          Write-Host 'No available upgrade found.'
          $global:LASTEXITCODE = -1978335189
          return
        }
        $global:LASTEXITCODE = 0
      }
      Start-GhcSection '' bootstrap
      Invoke-GhcStep '' winget {
        & ${JSON.stringify(wingetScriptPath)} -InstallPackage $installer
      }
      Complete-GhcSetup
      Write-Output "last:$($global:GhcWingetCalls[-1])"
    `)

    assert.equal(result.status, 0)
    assert.match(result.output, /│  Microsoft\.WindowsTerminal\.Preview is already current \(skipped\)/)
    assert.match(result.output, /╰─ ✓ all sections completed/)
    assert.match(result.output, /last:Cloudflare\.cloudflared$/)
  })

  it('rejects other winget failures without processing later packages', () => {
    const result = runPowerShellStepScript(String.raw`
      $global:GhcWingetCalls = [System.Collections.Generic.List[string]]::new()
      $installer = {
        param([string]$Package)
        [void]$global:GhcWingetCalls.Add($Package)
        $global:LASTEXITCODE = if ($Package -eq 'Microsoft.PowerToys') { 42 } else { 0 }
      }
      Start-GhcSection '' bootstrap
      Invoke-GhcStep '' winget {
        & ${JSON.stringify(wingetScriptPath)} -InstallPackage $installer
      } -Optional
      Write-Output "last:$($global:GhcWingetCalls[-1])"
      Complete-GhcSetup
    `)

    assert.equal(result.status, 1)
    assert.match(result.output, /│  \[setup winget\] failed to install Microsoft\.PowerToys \(exit code: 42\)\./)
    assert.match(result.output, /╰─ ✗ failed \(exit 42\); continuing/)
    assert.match(result.output, /last:Microsoft\.PowerToys/)
  })

  it('throws required failures without terminating the caller', () => {
    const result = runPowerShellStepScript(String.raw`
      $hostPath = (Get-Process -Id $PID).Path
      Start-GhcSection '' bootstrap
      try {
        Invoke-GhcStep '' broken {
          & $hostPath -NoProfile -NonInteractive -Command 'exit 23'
        }
        Write-Output unreachable
      } catch {
        Write-Output "caught exit $($_.Exception.Data['ExitCode'])"
      }
      Write-Output 'caller continued'
    `)

    assert.equal(result.status, 0)
    assert.doesNotMatch(result.output, /unreachable/)
    assert.match(result.output, /╰─ ✗ failed \(exit 23\); aborting/)
    assert.match(result.output, /caught exit 23/)
    assert.match(result.output, /caller continued$/)
  })

  it('keeps process environment mutations from child scopes', () => {
    const result = runPowerShellStepScript(String.raw`
      Start-GhcSection '' bootstrap
      Invoke-GhcStep '' environment {
        $env:GHC_STEP_TEST_MARKER = 'ready'
      }
      if ($env:GHC_STEP_TEST_MARKER -ne 'ready') {
        exit 91
      }
      Complete-GhcSetup
    `)

    assert.equal(result.status, 0)
    assert.match(result.output, /╰─ ✓ all sections completed$/)
  })

  it('suppresses successful preparation output and indents failure diagnostics', () => {
    const result = runPowerShellStepScript(String.raw`
      $tokens = $null
      $parseErrors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        ${JSON.stringify(powershellSetupPath)},
        [ref]$tokens,
        [ref]$parseErrors
      )
      $definition = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
          $node.Name -eq 'Invoke-GhcPreparationCommand'
      }, $true)
      Invoke-Expression $definition.Extent.Text

      $successOutput = @(Invoke-GhcPreparationCommand {
        Write-Output 'Already up to date.'
        $global:LASTEXITCODE = 0
      } 'sync failed')
      Write-Output "success-output:$($successOutput.Count)"

      try {
        Invoke-GhcPreparationCommand {
          Write-Output 'fatal diagnostic'
          $global:LASTEXITCODE = 42
        } 'sync failed'
      } catch {
        Write-Output $_.Exception.Message
      }
    `)

    assert.equal(result.status, 0)
    assert.doesNotMatch(result.output, /Already up to date/)
    assert.match(result.output, /^success-output:0$/m)
    assert.match(result.output, /^  fatal diagnostic$/m)
    assert.match(result.output, /sync failed \(exit code: 42\)\.$/)
  })

  it('keeps local settings outside the step wrapper', () => {
    const content = fs.readFileSync(powershellSetupPath, 'utf8')
    assert.match(content, /^Sync-GhcKitRepo$/m)
    assert.doesNotMatch(content, /Invoke-GhcStep[^\n]*local settings/)
  })

  it('prefers the local kit-repo binary', () => {
    const content = fs.readFileSync(powershellSetupPath, 'utf8')
    assert.match(content, /Join-Path \$cargoHome "local\\bin\\kit-repo\.exe"/)
    assert.match(content, /Test-Path -LiteralPath \$kitRepoBin -PathType Leaf/)
    assert.match(content, /Join-Path \$cargoHome "bin\\kit-repo\.exe"/)
  })

  it('runs shared configuration before the Windows-only Codex installer', () => {
    const content = fs.readFileSync(powershellSetupPath, 'utf8')
    const sync = content.indexOf('\nSync-GhcKitRepo\n')
    const config = content.indexOf('Invoke-GhcStep "" config')
    const codex = content.indexOf('Invoke-GhcStep "󰚩" codex')

    assert.ok(sync >= 0)
    assert.ok(sync < config)
    assert.ok(config < codex)
  })

  it('validates PowerShell and the Rust toolchain before persistent mutation', () => {
    const content = fs.readFileSync(powershellSetupPath, 'utf8')
    const firstPersistentMutation = content.indexOf(
      'Set-GhcUserEnvironmentVariable APP_HOME_MINIFORGE',
    )
    assert.ok(firstPersistentMutation > 0)
    const versionGuard = content.indexOf('$minimumPowerShellVersion')
    assert.ok(versionGuard >= 0)
    assert.ok(versionGuard < firstPersistentMutation)
    for (const command of ['cargo', 'rustc']) {
      const guard = content.indexOf('Get-Command ' + command)
      assert.ok(guard > 0)
      assert.ok(guard < firstPersistentMutation)
    }
    assert.match(content, /^\s*setx \$Name \$Value \*> \$null$/m)
    assert.doesNotMatch(content, /^\s*setx (?!\$Name)/m)
    assert.match(content, /\[setup preparation\] persisting user environment\.\.\./)
    assert.match(content, /function Invoke-GhcPreparationCommand/)
    assert.match(content, /\$output = @\(& \$Action 2>&1\)/)
    assert.match(content, /\[setup preparation\] syncing repository\.\.\./)

    const readme = fs.readFileSync(
      path.join(import.meta.dirname, '../README.md'),
      'utf8',
    )
    assert.match(readme, /pwsh -NoProfile -Command/)
  })
})
