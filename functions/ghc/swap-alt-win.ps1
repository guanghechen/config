function swap-alt-win {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("on", "off")]
        [string]$Mode
    )

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout"
    $regName = "Scancode Map"

    if ($Mode -eq "on") {
        # Swap only left Alt(0x38) and left Win(0x5B)
        $scancode = [byte[]](
            0x00,0x00,0x00,0x00,
            0x00,0x00,0x00,0x00,
            0x03,0x00,0x00,0x00,
            0x5B,0x00,0x38,0x00,
            0x38,0x00,0x5B,0x00,
            0x00,0x00,0x00,0x00
        )
        Set-ItemProperty -Path $regPath -Name $regName -Value $scancode
        Write-Host "✅ Alt/Win key swap enabled (left side only). Please restart system to take effect." -ForegroundColor Green
    }
    elseif ($Mode -eq "off") {
        Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        Write-Host "♻️ Default key mapping restored. Please restart system to take effect." -ForegroundColor Yellow
    }
}

