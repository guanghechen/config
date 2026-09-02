import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'

const installerPath = path.join(import.meta.dirname, '../setup/nix/env/kit-repo.bash')
const windowsInstallerPath = path.join(import.meta.dirname, '../setup/win/env/kit-repo.ps1')
const bashExecutable = process.platform === 'win32'
  ? [
      process.env.APP_HOME_GIT && path.join(process.env.APP_HOME_GIT, 'bin/bash.exe'),
      'C:\\app\\git\\bin\\bash.exe',
      'C:\\Program Files\\Git\\bin\\bash.exe',
    ].find(candidate => candidate && fs.existsSync(candidate)) ?? 'bash'
  : 'bash'

describe('kit-repo setup', () => {
  it('does not invoke cargo when the local Unix binary exists', {
    skip: process.platform === 'win32',
  }, () => {
    const testRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'kit-repo-setup-'))
    try {
      const cargoHome = path.join(testRoot, 'cargo')
      const localBinary = path.join(cargoHome, 'local/bin/kit-repo')
      const stubBin = path.join(testRoot, 'stub/bin')
      const cargoStub = path.join(stubBin, 'cargo')
      const cargoMarker = path.join(testRoot, 'cargo-called')
      fs.mkdirSync(path.dirname(localBinary), { recursive: true })
      fs.mkdirSync(stubBin, { recursive: true })
      fs.writeFileSync(localBinary, '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 })
      fs.writeFileSync(cargoStub, `#!/usr/bin/env bash\ntouch ${JSON.stringify(cargoMarker)}\nexit 99\n`, {
        mode: 0o755,
      })

      const result = spawnSync(
        bashExecutable,
        ['--noprofile', '--norc', installerPath],
        {
          encoding: 'utf8',
          env: {
            ...process.env,
            CARGO_HOME: cargoHome,
            PATH: `${stubBin}${path.delimiter}${process.env.PATH ?? ''}`,
          },
        },
      )

      assert.equal(result.status, 0, result.stderr)
      assert.match(result.stdout, /using local development binary:/)
      assert.equal(fs.existsSync(cargoMarker), false)
    } finally {
      fs.rmSync(testRoot, { recursive: true, force: true })
    }
  })

  it('guards the Windows cargo install with the local binary check', () => {
    const content = fs.readFileSync(windowsInstallerPath, 'utf8')
    const localCheck = content.indexOf('Test-Path -LiteralPath $localBinary -PathType Leaf')
    const cargoInstall = content.indexOf('cargo install --locked')

    assert.ok(localCheck >= 0)
    assert.ok(localCheck < cargoInstall)
    assert.match(content, /if \(Test-Path[^}]+\} else \{[\s\S]+cargo install --locked/)
  })
})
