# Gets the current role from classes.txt
$ErrorActionPreference = "SilentlyContinue"
if (Test-Path 'C:\\ProgramData\\PuppetLabs\\puppet\\cache\\state\\classes.txt') {
  Write-Output $(findstr "role::" C:\\ProgramData\\PuppetLabs\\puppet\\cache\\state\\classes.txt)
}


