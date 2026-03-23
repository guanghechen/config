param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$downloadUrl        = "https://github.com/guanghechen/mirror/releases/download/font/MapleMono-NF-CN-unhinted.zip"
$downloadDir        = Join-Path $env:USERPROFILE "download\fonts\Maple"
$zipPath            = Join-Path $downloadDir "MapleMono-NF-CN-unhinted.zip"
$expectedZipSha256  = "ab88522932cf4015dffeaef6dedc59a22a5fefecdcc6e583d9fcd997da5b7cac"
$userFontDir        = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$systemFontDir      = Join-Path $env:WINDIR "Fonts"
$userRegistryPath   = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
$systemRegistryPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

$expectedMapleFontFiles = @(
  "MapleMono-NF-CN-Bold.ttf",
  "MapleMono-NF-CN-BoldItalic.ttf",
  "MapleMono-NF-CN-ExtraBold.ttf",
  "MapleMono-NF-CN-ExtraBoldItalic.ttf",
  "MapleMono-NF-CN-ExtraLight.ttf",
  "MapleMono-NF-CN-ExtraLightItalic.ttf",
  "MapleMono-NF-CN-Italic.ttf",
  "MapleMono-NF-CN-Light.ttf",
  "MapleMono-NF-CN-LightItalic.ttf",
  "MapleMono-NF-CN-Medium.ttf",
  "MapleMono-NF-CN-MediumItalic.ttf",
  "MapleMono-NF-CN-Regular.ttf",
  "MapleMono-NF-CN-SemiBold.ttf",
  "MapleMono-NF-CN-SemiBoldItalic.ttf",
  "MapleMono-NF-CN-Thin.ttf",
  "MapleMono-NF-CN-ThinItalic.ttf"
)

$managedMapleFontFileSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($fontFileName in $expectedMapleFontFiles) {
  [void]$managedMapleFontFileSet.Add($fontFileName)
}

$managedMapleRegistryNameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($fontFileName in $expectedMapleFontFiles) {
  $fontType = if ([System.IO.Path]::GetExtension($fontFileName).ToLowerInvariant() -eq ".otf") { "OpenType" } else { "TrueType" }
  $fontNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fontFileName)
  $registryName = "$fontNameWithoutExtension ($fontType)"
  [void]$managedMapleRegistryNameSet.Add($registryName)
}

$legacyMapleFontFileNameRegex = '^MapleMonoNormalNL-NF-CN-[A-Za-z]+(?:Italic)?\.(ttf|otf|ttc)$'

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsMapleFontFileName {
  param(
    [string]$FileName
  )

  if ([string]::IsNullOrWhiteSpace($FileName)) {
    return $false
  }

  return $managedMapleFontFileSet.Contains($FileName) -or ($FileName -match $legacyMapleFontFileNameRegex)
}

function Get-FontFileNameFromRegistryValue {
  param(
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }

  $leaf = Split-Path -Path $Value -Leaf -ErrorAction SilentlyContinue
  if ([string]::IsNullOrWhiteSpace($leaf)) {
    return $Value
  }

  return $leaf
}

function Test-IsMapleRegistryItem {
  param(
    [string]$Name,
    [string]$Value
  )

  if (-not [string]::IsNullOrWhiteSpace($Name) -and $managedMapleRegistryNameSet.Contains($Name)) {
    return $true
  }

  $valueFileName = Get-FontFileNameFromRegistryValue -Value $Value

  return Test-IsMapleFontFileName -FileName $valueFileName
}

function Get-MapleRegistryItems {
  param(
    [string]$RegistryPath
  )

  $fontRegistry = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
  if ($null -eq $fontRegistry) {
    return @()
  }

  return @(
    $fontRegistry.PSObject.Properties |
      Where-Object {
        $_.MemberType -eq "NoteProperty" -and (Test-IsMapleRegistryItem -Name ([string]$_.Name) -Value ([string]$_.Value))
      }
  )
}

function Test-MapleInstalledAt {
  param(
    [string]$FontDir
  )

  $installedFontNames = @(
    Get-ChildItem -Path $FontDir -File -ErrorAction SilentlyContinue |
      Where-Object { Test-IsMapleFontFileName -FileName $_.Name } |
      ForEach-Object { $_.Name }
  )
  $missingFontFiles = @($expectedMapleFontFiles | Where-Object { $installedFontNames -notcontains $_ })
  return $missingFontFiles.Count -eq 0
}

function Remove-MapleFontsAt {
  param(
    [string]$FontDir,
    [string]$RegistryPath
  )

  Get-ChildItem -Path $FontDir -File -ErrorAction SilentlyContinue |
    Where-Object { Test-IsMapleFontFileName -FileName $_.Name } |
    Remove-Item -Force -ErrorAction SilentlyContinue

  Get-MapleRegistryItems -RegistryPath $RegistryPath |
    ForEach-Object {
      Remove-ItemProperty -Path $RegistryPath -Name $_.Name -ErrorAction SilentlyContinue
    }
}

function Invoke-ElevatedSelf {
  param(
    [switch]$Force
  )

  if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
    throw "Unable to relaunch script with elevation because PSCommandPath is empty."
  }

  $hostPath = (Get-Process -Id $PID).Path
  $arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $PSCommandPath
  )
  if ($Force) {
    $arguments += "-Force"
  }

  try {
    $process = Start-Process -FilePath $hostPath -ArgumentList $arguments -Verb RunAs -Wait -PassThru
  } catch {
    throw "Failed to elevate script (UAC cancelled or blocked): $($_.Exception.Message)"
  }

  if ($process.ExitCode -ne 0) {
    throw "Elevated font setup failed with exit code $($process.ExitCode)."
  }
}

$installedInUserScope = Test-MapleInstalledAt -FontDir $userFontDir
$installedInSystemScope = Test-MapleInstalledAt -FontDir $systemFontDir
$installedInAnyScope = $installedInUserScope -or $installedInSystemScope

if ((-not $Force) -and $installedInAnyScope) {
  Write-Host "  [setup font (Maple)] Maple is already installed in user/system scope. (skipped)" -ForegroundColor Yellow
  return
}

if (-not (Test-IsAdmin)) {
  Write-Host "  [setup font (Maple)] requesting Administrator permission..." -ForegroundColor Cyan
  Invoke-ElevatedSelf -Force:$Force
  return
}

if ($Force -and $installedInAnyScope) {
  Write-Host "  [setup font (Maple)] force removing existing MapleMono-NF-CN fonts..." -ForegroundColor Cyan
}

Remove-MapleFontsAt -FontDir $userFontDir -RegistryPath $userRegistryPath
Remove-MapleFontsAt -FontDir $systemFontDir -RegistryPath $systemRegistryPath

New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
Remove-Item -Path (Join-Path $downloadDir "*") -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "  [setup font (Maple)] downloading MapleMono-NF-CN fonts..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

$zipSha256 = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($zipSha256 -ne $expectedZipSha256) {
  throw "Maple font archive checksum mismatch. Expected: $expectedZipSha256, Actual: $zipSha256"
}

Write-Host "  [setup font (Maple)] installing MapleMono fonts..." -ForegroundColor Cyan
Expand-Archive -Path $zipPath -DestinationPath $downloadDir -Force
Remove-Item -Path $zipPath -Force

$fontFiles = @(
  Get-ChildItem -Path $downloadDir -Recurse -File |
    Where-Object { $_.Extension -in @(".ttf", ".otf", ".ttc") -and ($expectedMapleFontFiles -contains $_.Name) }
)

$actualFontNames = @($fontFiles | ForEach-Object { $_.Name })
$missingFontFiles = @($expectedMapleFontFiles | Where-Object { $actualFontNames -notcontains $_ })
if ($missingFontFiles.Count -gt 0) {
  throw "Maple font archive is missing expected files: $($missingFontFiles -join ', ')"
}

New-Item -ItemType Directory -Path $systemFontDir -Force | Out-Null
New-Item -Path $systemRegistryPath -Force | Out-Null

foreach ($fontFile in $fontFiles) {
  $targetPath = Join-Path $systemFontDir $fontFile.Name
  Copy-Item -Path $fontFile.FullName -Destination $targetPath -Force

  $fontType = if ($fontFile.Extension.ToLowerInvariant() -eq ".otf") { "OpenType" } else { "TrueType" }
  $registryName = "$($fontFile.BaseName) ($fontType)"
  New-ItemProperty -Path $systemRegistryPath -Name $registryName -PropertyType String -Value $fontFile.Name -Force | Out-Null
}

$installedSystemFontNames = @(
  Get-ChildItem -Path $systemFontDir -File -ErrorAction SilentlyContinue |
    Where-Object { Test-IsMapleFontFileName -FileName $_.Name } |
    ForEach-Object { $_.Name }
)
$missingInstalledFiles = @($expectedMapleFontFiles | Where-Object { $installedSystemFontNames -notcontains $_ })
if ($missingInstalledFiles.Count -gt 0) {
  throw "Maple font installation incomplete. Missing installed files: $($missingInstalledFiles -join ', ')"
}

$installedRegistryItems = @(Get-MapleRegistryItems -RegistryPath $systemRegistryPath)
if ($installedRegistryItems.Count -ne $expectedMapleFontFiles.Count) {
  throw "Maple font registry entries are incomplete. Expected $($expectedMapleFontFiles.Count), actual $($installedRegistryItems.Count)."
}

Write-Host "  [setup font (Maple)] done. Installed to $systemFontDir" -ForegroundColor Green
