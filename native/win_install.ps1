Param (
    [switch]$Uninstall = $false,
    [string]$DebugDirBase = "",
    [string]$InstallDirBase = ""
)

#
# Global constants
#
$global:InstallDirName = ".tridactyl"
$global:MessengerBinName = "native_main.py"
$global:MessengerBinWrapperFilename = "native_main.bat"
$global:MessengerManifestFilename = "tridactyl.json"
$global:PythonVersionStr = "Python 3"
$global:MessengerManifestReplaceStr = "REPLACE_ME_WITH_SED"

$global:MessengerFilesHttpUriBase = [string]::Format("{0}{1}",
    "https://raw.githubusercontent.com",
    "/cmcaine/tridactyl/master/native")

$global:MessengerManifestRegistryPath = `
    "HKCU:\Software\Mozilla\NativeMessagingHosts\tridactyl"

$global:Uninstall = $Uninstall
$global:InstallDirBase = $InstallDirBase.Trim()
$global:DebugDirBase = $DebugDirBase.Trim()

function Get-PythonVersionStatus() {
    try {
        $pythonVersion = py -3 -u --version
    } catch {
        $pythonVersion = ""
    }

    if ($pythonVersion.IndexOf($global:PythonVersionStr) -ge 0) {
        return $true
    } else {
        return $false
    }
}

function Set-MessengerUninstall() {
    Write-Host "[+] Uninstalling Tridactyl native-messenger ..."

    $messengerBinPath = Get-MessengerBinPath
    $messengerBinWrapperPath = Get-MessengerBinWrapperPath
    $messengerManifestPath = Get-MessengerManifestPath

    $result = Remove-TridactylPath $messengerBinPath
    $result = Remove-TridactylPath $messengerBinWrapperPath
    $result = Remove-TridactylPath $messengerManifestPath

    $result1 = Test-TridactylPath $messengerBinPath
    $result2 = Test-TridactylPath $messengerBinWrapperPath
    $result3 = Test-TridactylPath $messengerManifestPath
    $result4 = Remove-MessengerManifestRegistry

    if (($result1 -eq $false) `
        -and ($result2 -eq $false) `
        -and ($result3 -eq $false) `
        -and ($result4 -eq $true)) {
        Write-Host "[+] Uninstallation successful! :-)"
    } else {
        Write-Host "[+] Uninstallation failed. :-("
    }
}

function Remove-TridactylPath() {
    Param([string]$path)

    if (! (Test-Path $path)) {
        return
    }

    Write-Host `
        -NoNewline `
        "    - Removing $path "

    $result = Remove-Item `
        -Force `
        -Recurse `
        -Path $path

    if ($result -eq 0) {
        Write-Host "was successful!"
        return $true
    }
    else {
        Write-Host "failed."
        return $false
    }
}

function Test-TridactylPath() {
    Param([string]$path)

    Write-Host `
        -NoNewline `
        "    - Testing $path "

    if((Test-Path $path)) {
        Write-Host "was successful!"
        return $true
    }
    else {
        Write-Host "failed."
        return $false
    }
}

function Get-MessengerInstallDir() {
    if (($InstallDirBase.Length -gt 0) `
        -and (Test-Path $InstallDirBase.Trim())) {
        $messengerInstallDir = [string]::Format("{0}\{1}",
            $global:InstallDirBase,
            $global:InstallDirName
        )
    } else {
        $messengerInstallDir = [string]::Format("{0}\{1}",
            $env:USERPROFILE,
            $global:InstallDirName
        )
    }

    return $messengerInstallDir.Trim()
}

function Set-InstallDir() {
    $messengerInstallDir = Get-MessengerInstallDir
    Write-Host "[+] Preparing $messengerInstallDir ..."

    If(! (Test-Path $messengerInstallDir)) {
        New-Item -ItemType Directory `
            -Force `
            -Path $messengerInstallDir | Out-Null
    } else {
        Write-Host `
            "    - $messengerInstallDir exists, moving on ..."
    }

    $result = Test-TridactylPath $messengerInstallDir
    if ($result -eq $true) {
        Write-Host `
            "    - Creating $messengerInstallDir was successful!"
            return $true
    } else {
        Write-Host `
            "    - Creating $messengerInstallDir failed, quitting ..."
        exit -1
    }
}

function Get-MessengerBinPath() {
    $messengerInstallDir = Get-MessengerInstallDir

    $native_messenger_binary_path = [string]::Format("{0}\{1}",
        $messengerInstallDir,
        $global:MessengerBinName)

    Return $native_messenger_binary_path.Trim()
}

function Get-MessengerBinUri() {
    $downloadStartTime = (Get-Date `
        -Date ((Get-Date).ToUniversalTime()) `
        -UFormat %s)

    $messengerBinUri = [string]::Format("{0}/{1}?{2}",
        $global:MessengerFilesHttpUriBase,
        $global:MessengerBinName,
        $downloadStartTime)

    Return $messengerBinUri.Trim()
}

function Set-MessengerBin() {
    $messengerBinPath = Get-MessengerBinPath
    $messengerBinUri = Get-MessengerBinUri

    if ($global:DebugDirBase.Length -gt 0) {
        $srcPath = [string]::Format("{0}\{1}",
            $global:DebugDirBase,
            $global:MessengerBinName)

        Write-Host "[+] Copying $srcPath ..."

        Copy-Item `
            -Path $srcPath `
            -Destination $messengerBinPath
    } else {
        Write-Host "[+] Downloading $messengerBinUri ..."

        try {
            Invoke-WebRequest `
                -Uri $messengerBinUri `
                -OutFile $messengerBinPath
        } catch {
            Write-Host `
                "Invoke-WebRequest StatusCode:" `
                $_.Exception.Response.StatusCode.value__

            Write-Host `
                "Invoke-WebRequest StatusDescription:" `
                $_.Exception.Response.StatusDescription

            Write-Host "[+] Downloading failed, quitting ..."
            exit -1
        }
    }

    $result = Test-TridactylPath -Path $messengerBinPath
    if ($result -eq $true) {
        Write-Host `
            "    - Creating $messengerBinPath was successful!"
        return $true
    } else {
        Write-Host `
            "    - Creating $messengerBinPath failed, quitting ..."
        exit -1
    }
}

function Get-MessengerBinWrapperPath() {
    $messengerInstallDir = Get-MessengerInstallDir

    $messengerBinWrapperPath = [string]::Format("{0}\{1}",
        $messengerInstallDir,
        $global:MessengerBinWrapperFilename)

    Return $messengerBinWrapperPath.Trim()
}

function Set-MessengerBinWrapper() {
    $messengerBinPath = Get-MessengerBinPath
    $messengerBinWrapperPath = Get-MessengerBinWrapperPath
    $messengerWrapperContent = @"
@echo off
call py -3 -u $messengerBinPath
"@

    Write-Host "[+] Preparing $messengerBinWrapperPath ..."

    $messengerWrapperContent `
        | Out-File `
        -Encoding ascii `
        -FilePath $messengerBinWrapperPath

    $result = Test-TridactylPath -Path $messengerBinWrapperPath
    if ($result -eq $true) {
        $msg = [string]::Format(
                "    - Creating {0} was successful!",
                $messengerBinWrapperPath)
        Write-Host $msg
        return $true
    } else {
        $msg = [string]::Format(
                "    - Creating {0} failed, quitting ...",
                $messengerBinWrapperPath)
        Write-Host $msg
        exit -1
    }
}

function Get-MessengerManifestPath() {
    $messengerInstallDir = Get-MessengerInstallDir

    $messengerManifestPath = [string]::Format("{0}\{1}",
        $messengerInstallDir,
        $global:MessengerManifestFilename)

    return $messengerManifestPath.Trim()
}

function Get-MessengerManifestUri() {
    $downloadStartTime = (Get-Date `
        -Date ((Get-Date).ToUniversalTime()) `
        -UFormat %s)

    $messengerManifestUri = [string]::Format("{0}/{1}?{2}",
        $global:MessengerFilesHttpUriBase,
        $global:MessengerManifestFilename,
        $downloadStartTime)

    return $messengerManifestUri.Trim()
}

function Set-MessengerManifest() {
    $messengerManifestPath = Get-MessengerManifestPath
    $messengerManifestUri = Get-MessengerManifestUri
    $result = $false

    if ($global:DebugDirBase.Length -gt 0) {
        $srcPath = [string]::Format("{0}\{1}",
            $global:DebugDirBase,
            $global:MessengerManifestFilename)

        Write-Host "[+] Copying $srcPath ..."

        Copy-Item `
            -Path $srcPath `
            -Destination $messengerManifestPath
    } else {
        Write-Host "[+] Downloading $messengerManifestUri ..."

        try {
            Invoke-WebRequest `
                -Uri $messengerManifestUri `
                -OutFile $messengerManifestPath
        } catch {
            Write-Host `
            "Invoke-WebRequest StatusCode:" `
            $_.Exception.Response.StatusCode.value__

            Write-Host `
                "Invoke-WebRequest StatusDescription:" `
                $_.Exception.Response.StatusDescription

            Write-Host "    - Downloading failed, quitting ..."
            exit -1
        }
    }

    $result = Test-TridactylPath -Path $messengerManifestPath

    if ($result -eq $true) {
        $msg = [string]::Format(
                "    - Creating {0} was successful!",
                $messengerManifestPath)
        Write-Host $msg
    } else {
        $msg = [string]::Format(
                "    - Creating {0} failed, quitting ...",
                $messengerManifestPath)
        Write-Host $msg
        exit -1
    }

    (Get-Content `
        $messengerManifestPath).replace( `
            $MessengerManifestReplaceStr, `
            $MessengerBinWrapperFilename) `
        | Set-Content -Encoding ascii $messengerManifestPath

    $found_pattern = (Select-String `
        -Path $messengerManifestPath `
        -Pattern $MessengerManifestReplaceStr `
        -CaseSensitive `
        | Select-Object Line)

    if (! $found_pattern) {
        Write-Host `
            "    - Patching $messengerManifestPath was successful!"
    }

    return $result
}

function Get-MessengerManifestRegistry(){
    $msg = [string]::Format("[+] Getting registry key {0} ...",
        $global:MessengerManifestRegistryPath)

    Write-Host $msg

    $registry = Get-Item `
        -Path "$global:MessengerManifestRegistryPath" `
        -ErrorAction SilentlyContinue

    return $registry
}

function Get-MessengerManifestRegistryValue(){
    $msg = [string]::Format( `
        "[+] Getting (Default) registry value {0} ...",
        $global:MessengerManifestRegistryPath)

    Write-Host $msg

    $registryKey = Get-MessengerManifestRegistry
    $registryValue = ""

    if ($registryKey) {
        $registryValue = $registryKey."(Default)" `
            -eq $messengerManifestPath
    }

    return $registryValue
}

function Remove-MessengerManifestRegistry() {
    $msg = [string]::Format("[+] Removing registry key {0} ...",
        $global:MessengerManifestRegistryPath)

    Write-Host $msg

    Remove-Item `
        -Path "$global:MessengerManifestRegistryPath" `
        -Force `
        -ErrorAction SilentlyContinue

    $registryExists = Get-MessengerManifestRegistry

    if (! $registryExists) {
        Write-Host "    - Removing registry was successful!"
        return $true
    } else {
        Write-Host "    - Removing registry failed, quitting ..."
        exit -1
    }
}
function Set-MessengerManifestRegistry() {
    $messengerManifestPath = Get-MessengerManifestPath

    $msg = [string]::Format("[+] Adding registry key {0} ...",
        $global:MessengerManifestRegistryPath)

    Write-Host $msg

    New-Item `
        -Path $global:MessengerManifestRegistryPath `
        -Force | Out-Null

    New-ItemProperty `
        -Path $global:MessengerManifestRegistryPath `
        -Name "(Default)" `
        -Value $messengerManifestPath `
        -Force | Out-Null

    if ((Get-ItemProperty `
        -Path $MessengerManifestRegistryPath)."(Default)" `
            -eq $messengerManifestPath) {
        Write-Host "    - Adding registry was successful!"
        return $true
    } else {
        Write-Host "    - Adding registry failed, quitting ..."
        exit -1
    }
}

function Set-MessengerInstall() {
    # Check for Python 3
    Write-Host "[+] Looking for Python 3 ..."
    $pythonVersionStatus = Get-PythonVersionStatus
    if (! $pythonVersionStatus) {
        Write-Host "    - Python 3 not found, quitting ..."
        exit -1
    } else {
       $pythonPath = Get-Command "py" `
            | Select-Object -ExpandProperty "Source"

        Write-Host "    - Python 3 found at: $pythonPath"
    }

    # Prepare `.tridactyl` directory
    $result = Set-InstallDir

    # Prepare `native_main.py`
    if ($result -eq $true) {
        $result = Set-MessengerBin
    }

    # Prepare `native_main.bat`
    if ($result -eq $true) {
        $result = Set-MessengerBinWrapper
    }

    # Prepare `tridactyl.json`
    if ($result -eq $true) {
        $result = Set-MessengerManifest
    }

    ## Add registry entry
    if ($result -eq $true) {
        $result = Set-MessengerManifestRegistry
    }

    #
    # If we are here passing all the checks above, installation is
    # highly likely to have gone as expected. Let's do some final
    # sanity checks before declaring "victory"!
    #

    Write-Host "[+] Cross-checking everything ..."
    $result1 = Test-TridactylPath (Get-MessengerManifestPath)
    $result2 = Test-TridactylPath (Get-MessengerBinPath)
    $result3 = Test-TridactylPath (Get-MessengerBinWrapperPath)
    $result4 = Get-MessengerManifestRegistryValue

    if (($result1 -eq $true) `
        -and ($result2 -eq $true) `
        -and ($result3 -eq $true) `
        -and ($result4)) {
        Write-Host "[+] Installation successful!"
        Write-Host "    - Run ':native' in Firefox to cross-check. :-)"
    } else {
        Write-Host "[+] Installation failed. :-("
    }
}

## Perform `Uninstall` if requested
if ($global:Uninstall) {
    Set-MessengerUninstall
    exit 0
}

Set-MessengerInstall

