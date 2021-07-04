<#
.NOTES
	Name: ForceShellExecute.ps1
	Author: Bela Bana | https://github.com/belabana
    Request: I needed to automate the deployment of a registry key to fix a Microsoft Office related issue on 150+ workstations.
             Then I upgraded my script to identify and show the architecture as well as version of MS Office installed on the PCs. 
    Reference: https://docs.microsoft.com/en-US/office/troubleshoot/office-suite-issues/cannot-locate-server-when-click-hyperlink
    Supported MS Office versions: 2013, 2016
    Classification: Public
    Disclaimer: Author does not take responsibility for any unexpected outcome that could arise from using this script.
                Please always test it in a virtual lab or UAT environment before executing it in production environment.
    
.SYNOPSIS
    Identify architecture and version of the installed Microsoft Office package and deploy registry fix as per the reference MS article.

.DESCRIPTION
    This script will help you detect the architecture as well as version of the Microsoft Office installed on a computer.
    It will inject a registry key with a specific value to the correct subkey. 
#>
$bitness=0
$versions="15.0","16.0"
ForEach ($version in $versions) {
    try {
        $bitness= Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\$version\Outlook -name Bitness -ErrorAction Stop
    }
    catch {
        foreach ($version in $versions) {
            try {
                $bitness= Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Office\$version\Outlook -name Bitness -ErrorAction Stop
            }
            catch {
                Write-Host -ForegroundColor Red "Office $version not found."
            }
        }
    }
}
if ($bitness -eq 0) {
    Write-Host -ForegroundColor Red "There is no supported Office installation found."
}
else {
    #Identifying version of Office
    $installedversion=$bitness.PSParentPath.Substring($bitness.PSParentPath.get_Length()-4)
    if ($installedversion -eq "15.0") { Write-Host "Version of Office: 2013" }
    elseif ($installedversion -eq "16.0") { Write-Host "Version of Office: 2016" }
    
    #Identifying architecture of Office and deploying ForceShellExecute fix to registry
    if( $bitness.Bitness -eq "x86" ) { #For 32-bit version of Office
        Write-Host "Architecture of Office: 32-bit"
        reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\9.0\Common\Internet" /v ForceShellExecute /t REG_DWORD /d 1
    }
    Else #For 64-bit version of Office
    {
        Write-Host "Architecture of Office: 64-bit"
        reg add "HKLM\SOFTWARE\Microsoft\Office\9.0\Common\Internet" /v ForceShellExecute /t REG_DWORD /d 1
    }
}