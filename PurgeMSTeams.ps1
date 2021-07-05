<#
.NOTES
    Name: PurgeMSTeams.ps1
    Author: Bela Bana | https://github.com/belabana
    Story: I needed to automate the uninstallation of Microsoft Teams on multiple terminal servers.
    Classification: Public
    Disclaimer: Author does not take responsibility for any unexpected outcome that could arise from using this script.
                Please always test it in a virtual lab or UAT environment before executing it in production environment.
        
.SYNOPSIS
    Uninstall Microsoft Teams and flush cache for each user on a terminal server.

.DESCRIPTION
    This script will uninstall Microsoft Teams and clean up its cached data for each user on a terminal server.
    Transcript and timestamps are added to calculate runtime and write output to a .log file. Path: "C:\temp"
    It needs to be executed on the target RD server outside working hours because it also stops the Outlook process.
#>
begin {
#Start logging
$TranscriptPath = "C:\temp\PurgeMSTeams_$(Get-Date -Format yyyy-MM-dd-HH-mm).log"
Start-Transcript -Path $TranscriptPath
Write-Host -ForegroundColor Yellow "Script started: "(Get-Date -Format "dddd MM/dd/yyyy HH:mm")
[int]$StartTimer = (Get-Date).Second
#Get all users
$Users = Get-ChildItem -Path "$($ENV:SystemDrive)\Users"
#List affected users and request confirmation
Write-Warning "Would you like to uninstall Teams for the following users:`n$Users" -WarningAction Inquire
}
process {
#Stop relevant processes to avoid exceptions (i.e. meeting-addin)
Write-Host "Closing relevant processes.."
Stop-Process -Name "Outlook"
Stop-Process -Name "Teams"
Start-Sleep -s 8

#Proceed with uninstallation for all users
ForEach ($User in $Users) {
    $TeamsUpdateExePath = "C:\Users\$User\AppData\Local\Microsoft\Teams\Update.exe"
    $TeamsPath = "C:\Users\$User\AppData\Local\Microsoft\Teams"
    $TeamsCachePath = "C:\Users\$User\AppData\Roaming\Microsoft\Teams"
    Write-Host "Process user: $User" -ForegroundColor Yellow
    try {
        #Uninstall Teams
        if ([System.IO.File]::Exists($TeamsUpdateExePath)) {
            Write-Host "Uninstalling Teams.."
            $proc = Start-Process $TeamsUpdateExePath "-uninstall -s" -PassThru
            $proc.WaitForExit()
        }
        #Clean up Teams cache
        Write-Host "Cleaning up Teams cache folders.."
        Write-Host $TeamsPath
        Write-Host $TeamsCachePath
        Remove-Item –path $TeamsPath -recurse
        Remove-Item –path $TeamsCachePath -recurse
        }
    catch {
        Write-Output "Unable to uninstall MS Teams. Error: $_.exception.message"
        Exit /b 1
    }
}
Write-Host -ForegroundColor Yellow "Script ended: "(Get-Date -Format "dddd MM/dd/yyyy HH:mm")
[int]$EndTimer = (Get-Date).Second
Write-Host -ForegroundColor Yellow "Script completed in $([Math]::Abs($StartTimer - $EndTimer)) seconds."
Stop-Transcript
}
