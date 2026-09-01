# Shared forest and step helpers for the Windows setup entrypoint.
#
# The entrypoint declares flat sections. Each step is an independent, rounded
# tree whose combined output is streamed one level below its root. Optional
# failures are collected; required failures throw with the original exit code
# attached to the exception.

$script:GhcStepFailures = [System.Collections.Generic.List[string]]::new()
$script:GhcSection = ""
$script:GhcSectionHasStep = $false
$script:GhcColorReset = "`e[0m"
$script:GhcColorRail = "`e[90m"
$script:GhcColorHeading = "`e[1;95m"
$script:GhcColorStep = "`e[96m"
$script:GhcColorSuccess = "`e[92m"
$script:GhcColorError = "`e[91m"
$script:GhcColorWarning = "`e[93m"
$script:GhcColorSummary = "`e[95m"

function Write-GhcLine {
  param(
    [AllowEmptyString()]
    [string]$Text
  )

  [Console]::Out.WriteLine($Text)
}

function Get-GhcAnsiForeground {
  param(
    [Nullable[ConsoleColor]]$Color
  )

  if ($null -eq $Color) {
    return ""
  }

  $codes = @{
    Black       = 30
    DarkRed     = 31
    DarkGreen   = 32
    DarkYellow  = 33
    DarkBlue    = 34
    DarkMagenta = 35
    DarkCyan    = 36
    Gray        = 37
    DarkGray    = 90
    Red         = 91
    Green       = 92
    Yellow      = 93
    Blue        = 94
    Magenta     = 95
    Cyan        = 96
    White       = 97
  }
  $code = $codes[$Color.ToString()]
  if ($null -eq $code) {
    return ""
  }
  return "`e[${code}m"
}

function Write-GhcForestOutput {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true)]
    [AllowNull()]
    [object]$InputObject
  )

  process {
    if ($null -eq $InputObject) {
      return
    }

    $prefix = ""
    $text = $InputObject.ToString()
    if (
      $InputObject -is [System.Management.Automation.InformationRecord] -and
      $InputObject.MessageData -is [System.Management.Automation.HostInformationMessage]
    ) {
      $message = $InputObject.MessageData
      $prefix = Get-GhcAnsiForeground -Color $message.ForegroundColor
      $text = $message.Message
    }

    foreach ($line in ($text -split "`n")) {
      $normalized = ($line -split "`r")[-1]
      if ([string]::IsNullOrEmpty($normalized)) {
        continue
      }
      Write-GhcLine "$script:GhcColorRail│$script:GhcColorReset  $prefix$normalized$script:GhcColorReset"
    }
  }
}

function Start-GhcSection {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Icon,

    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  Write-GhcLine ""
  Write-GhcLine "$script:GhcColorHeading$Icon $Label$script:GhcColorReset"
  $script:GhcSection = $Label
  $script:GhcSectionHasStep = $false
}

function Start-GhcStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Icon,

    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  if ($script:GhcSectionHasStep) {
    Write-GhcLine ""
  }
  $script:GhcSectionHasStep = $true
  Write-GhcLine "$script:GhcColorRail╭─$script:GhcColorReset $script:GhcColorStep$Icon $Label$script:GhcColorReset"
}

function New-GhcStepFailureException {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $true)]
    [int]$ExitCode,

    [Exception]$InnerException
  )

  $exception = if ($null -eq $InnerException) {
    [InvalidOperationException]::new($Message)
  } else {
    [InvalidOperationException]::new($Message, $InnerException)
  }
  $exception.Data["ExitCode"] = $ExitCode
  return $exception
}

function Invoke-GhcStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Icon,

    [Parameter(Mandatory = $true)]
    [string]$Label,

    [Parameter(Mandatory = $true)]
    [scriptblock]$Action,

    [switch]$Optional
  )

  Start-GhcStep -Icon $Icon -Label $Label
  $global:LASTEXITCODE = 0
  $exitCode = 0
  $caughtException = $null
  try {
    $ErrorActionPreference = "Stop"
    $PSNativeCommandUseErrorActionPreference = $true
    & $Action *>&1 | Write-GhcForestOutput
    if ($global:LASTEXITCODE -ne 0) {
      $exitCode = $global:LASTEXITCODE
    }
  } catch {
    $_ | Write-GhcForestOutput
    $caughtException = $_.Exception
    $exitCode = if ($global:LASTEXITCODE -ne 0) { $global:LASTEXITCODE } else { 1 }
  }

  if ($exitCode -eq 0) {
    Write-GhcLine "$script:GhcColorRail╰─$script:GhcColorReset $script:GhcColorSuccess✓ done$script:GhcColorReset"
    return
  }

  if (-not $Optional) {
    Write-GhcLine "$script:GhcColorRail╰─$script:GhcColorReset $script:GhcColorError✗ failed (exit $exitCode); aborting$script:GhcColorReset"
    throw (New-GhcStepFailureException -Message "setup step '$Label' failed with exit code $exitCode" -ExitCode $exitCode -InnerException $caughtException)
  }

  Write-GhcLine "$script:GhcColorRail╰─$script:GhcColorReset $script:GhcColorError✗ failed (exit $exitCode); continuing$script:GhcColorReset"
  $failure = if ([string]::IsNullOrWhiteSpace($script:GhcSection)) {
    $Label
  } else {
    "$script:GhcSection / $Label"
  }
  [void]$script:GhcStepFailures.Add($failure)
}

function Skip-GhcStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Icon,

    [Parameter(Mandatory = $true)]
    [string]$Label,

    [Parameter(Mandatory = $true)]
    [string]$Reason
  )

  Start-GhcStep -Icon $Icon -Label $Label
  Write-GhcLine "$script:GhcColorRail╰─$script:GhcColorReset $script:GhcColorWarning○ skipped — $Reason$script:GhcColorReset"
}

function Assert-GhcCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Name
  )

  foreach ($command in $Name) {
    if (Get-Command $command -ErrorAction SilentlyContinue) {
      continue
    }
    throw "required command not found: $command"
  }
}

function Complete-GhcSetup {
  Write-GhcLine ""
  Write-GhcLine "$script:GhcColorHeading summary$script:GhcColorReset"
  Write-GhcLine "$script:GhcColorRail╭─$script:GhcColorReset $script:GhcColorSummary󰒓 setup$script:GhcColorReset"

  if ($script:GhcStepFailures.Count -eq 0) {
    Write-GhcLine "$script:GhcColorRail╰─$script:GhcColorReset $script:GhcColorSuccess✓ all sections completed$script:GhcColorReset"
    return
  }

  foreach ($failure in $script:GhcStepFailures) {
    Write-GhcLine "$script:GhcColorRail│$script:GhcColorReset  $script:GhcColorError$failure$script:GhcColorReset"
  }
  $noun = if ($script:GhcStepFailures.Count -eq 1) { "step" } else { "steps" }
  Write-GhcLine "$script:GhcColorRail╰─$script:GhcColorReset $script:GhcColorError✗ completed with $($script:GhcStepFailures.Count) failed $noun$script:GhcColorReset"
  throw (New-GhcStepFailureException -Message "setup completed with $($script:GhcStepFailures.Count) failed $noun" -ExitCode 1)
}
