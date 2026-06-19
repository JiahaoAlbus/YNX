param(
  [ValidateSet("full-node", "validator", "public-rpc")]
  [string]$Role = "full-node",
  [string]$Distro = "Ubuntu"
)

$ErrorActionPreference = "Stop"

function Write-Info($message) {
  Write-Host "[YNX] $message" -ForegroundColor Cyan
}

function Write-WarnMessage($message) {
  Write-Host "[YNX] $message" -ForegroundColor Yellow
}

function Write-Fail($message) {
  Write-Host "[YNX] $message" -ForegroundColor Red
}

function Require-Admin {
  $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please re-run PowerShell as Administrator. A clean Windows setup needs admin rights to enable WSL."
  }
}

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $name"
  }
}

function Get-DistroNames {
  $raw = & wsl.exe -l -q 2>$null
  if (-not $raw) {
    return @()
  }
  return ($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
}

function Ensure-UbuntuDistro($name) {
  $distros = Get-DistroNames
  if ($distros -contains $name) {
    return $true
  }

  Write-Info "WSL is available but distro '$name' is not installed. Installing it now."
  & wsl.exe --install -d $name
  Write-WarnMessage "WSL/$name installation has started."
  Write-WarnMessage "If Windows asks for a reboot or Ubuntu asks you to create the first Linux username, finish that first."
  Write-WarnMessage "Then re-run this same command to complete YNX installation."
  return $false
}

function Invoke-InUbuntu($distro, $role) {
  $linuxCommand = @"
set -euo pipefail
sudo apt-get update -y
sudo apt-get install -y curl git jq ca-certificates bash
curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
export PATH="\$HOME/.local/bin:\$PATH"
ynx help
ynx join-plan --role $role
echo
echo "YNX CLI is installed inside WSL ($distro)."
echo "Next command:"
echo "  ynx join --role $role"
"@

  & wsl.exe -d $distro -- bash -lc $linuxCommand
}

try {
  Require-Admin
  Require-Command "wsl.exe"

  Write-Info "Checking WSL availability..."
  $null = & wsl.exe --status 2>$null

  if (-not (Ensure-UbuntuDistro -name $Distro)) {
    exit 0
  }

  Write-Info "Running YNX installer inside WSL distro '$Distro'..."
  Invoke-InUbuntu -distro $Distro -role $Role
  Write-Info "Windows bootstrap completed."
} catch {
  Write-Fail $_.Exception.Message
  exit 1
}
