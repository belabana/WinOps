<#
.NOTES
	Name: GetNTP.ps1
	Author: Bela Bana | https://github.com/belabana
    Request: I needed to automate the task to query NTP settings from multiple Domain Controllers.
    Classification: Public
    Disclaimer: Author does not take responsibility for any unexpected outcome that could arise from using this script.
                Please always test it in a virtual lab or UAT environment before executing it in production environment.
        
.SYNOPSIS
    Qaury the current NTP configuration from the specified PDC Emulator as well as Domain Controllers.

.DESCRIPTION
    This script will query the NTP settings of the specified Domain Controllers.
    Transcript and timestamps are added to calculate runtime and write output to a .log file. Path: “C:\temp”
    It should be executed with a Domain Administrator account from a Domain Controller.

.PARAMETER PDCEmulator
    The hostname of PDC Emulator. This machine syncs time from the preferred external NTP source.

.PARAMETER DCControllers
    The list of Domain Controllers except the PDCEmulator. These machines use W32Time service to sync time across the domain.

.PARAMETER Credential
    Credentials of a user with Domain Administrator access.
#>
param(
    [parameter(Mandatory=$true)]
    [System.String] $PDCEmulator,

    [parameter(Mandatory=$true)]
    [System.String[]] $DCControllers,

    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential] $ADAdminCredential
)
begin {
$TranscriptPath = "C:\temp\GetNTP_$(Get-Date -Format yyyy-MM-dd-HH-mm).log"
Start-Transcript -Path $TranscriptPath
Write-Host -ForegroundColor Yellow "Script started: "(Get-Date -Format "dddd MM/dd/yyyy HH:mm")
#Variables
[int]$StartTimer = (Get-Date).Second

#Functions
Function Query-DomainController ($DomainController) {
    Write-Host -ForegroundColor Yellow "Querying $DomainController.."
    try {
        #Connect to a Domain Controller and query its NTP configuration
        $s = New-PSSession -ComputerName $DomainController
        Invoke-Command -Session $s -ScriptBlock {w32tm /query /configuration}
        Start-Sleep -Seconds 5
        Write-Host -ForegroundColor Green "Contacted $DomainController successfully."
        Remove-PSSession $s;     
    }
    catch {
        Write-Host -ForegroundColor Red "Unable to talk to $DomainController."
        Write-Error -Message "$_" -ErrorAction Continue
        return;
    }
}
Write-Warning "Would you like to query NTP settings from the following Domain Controllers:`n$PDCEmulator,$DCControllers" -WarningAction Inquire
}
process {
#Query the PDC Emulator
Write-Host -ForegroundColor Yellow "Querying $PDCEmulator.."
try {
    #Connect to the PDC Emulator and get its NTP settings
    $s = New-PSSession -ComputerName $PDCEmulator
    Invoke-Command -Session $s -ScriptBlock {w32tm /query /configuration}
    Write-Host -ForegroundColor Green "Contacted $PDCEmulator successfully."
    Remove-PSSession $s;     
}
catch {
    Write-Host -ForegroundColor Red "Unable to talk to $PDCEmulator."
    Write-Error -Message "$_" -ErrorAction Stop
    return;
}
#Freeze time
Start-Sleep -Seconds 5

#Query Domain Controllers
ForEach ($DCController in $DCControllers) {
    Query-DomainController -DomainController $DCController
}
}
end {
Write-Host -ForegroundColor Yellow "Script ended: "(Get-Date -Format "dddd MM/dd/yyyy HH:mm")
[int]$EndTimer = (Get-Date).Second
Write-Host -ForegroundColor Yellow "Script completed in $([Math]::Abs($StartTimer - $EndTimer)) seconds."
Stop-Transcript
}