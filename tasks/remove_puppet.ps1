# Stops puppet services, uninstalls puppet and removes directories
$ErrorActionPreference = "SilentlyContinue"
$puppet_data_dir = 'C:\\ProgramData\\PuppetLabs'
$puppet_prog_dir = 'C:\\Program Files\\PuppetLabs'

# Stop services
net stop puppet
net stop pxp-agent
net stop mcollective

# Uninstall package if present
$puppet_package = get-wmiobject Win32_Product | Where-Object {$_.Name -eq "Puppet Agent (64-bit)"}
if ($puppet_package) {
  msiexec /qn /norestart /x $puppet_package.LocalPackage
}

# Wait up to 2 minutes for completion of uninstall
$count = 0
while ( (get-wmiobject Win32_Product | Where-Object {$_.Name -eq "Puppet Agent (64-bit)"}) -and ($count -lt 24) ) {
  Start-Sleep -s 5
  $count++
}
if ($count -eq 12) {
  Write-Error "Uninstall took more than two minutes, it might be hanging or have failed."
}

# Wait for msiexec to complete clean-up
Start-Sleep -s 15

# Remove files and directories left behind by uninstall
if (Test-Path "$puppet_data_dir") {
  Remove-Item -force -recurse "$puppet_data_dir"
}
if (Test-Path "$puppet_prog_dir") {
  Remove-Item -force -recurse "$puppet_prog_dir"
}

# Wait for NTFS to flush writes to disk
Start-Sleep -s 1

# Check if removal was succesfull
if (Test-Path "$puppet_data_dir") {
  Write-Error "Failed to remove $puppet_data_dir."
}
if (Test-Path "$puppet_prog_dir") {
  Write-Error "Failed to remove $puppet_prog_dir."
}


