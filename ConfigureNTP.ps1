<#
.NOTES
    Name: ConfigureNTP.ps1
    Author: Bela Bana | https://github.com/belabana
    Request: I needed to reconfigure NTP settings for multiple Domain Controllers at once.
    Classification: Public
    Disclaimer: Author does not take responsibility for any unexpected outcome that could arise from using this script.
                Please always test it in a virtual lab or UAT environment before executing it in production environment.
        
.SYNOPSIS
    Set external NTP source for a PDC Emulator and configure W32Time service for the additional Domain Controllers.

.DESCRIPTION
    This script will reconfigure NTP settings for the specified Domain Controllers.
    You need to define the FQDN of the external NTP source server, a PDC Emulator and all the other Domain Controllers.
    Transcript and timestamps are added to calculate runtime and write output to a .log file. Path: “C:\temp”
    It should be executed with elevated access by a Domain Administrator from a Domain Controller.

.PARAMETER NTPSource
    The FQDN of the desired external NTP service. Recommended value: time.windows.com

.PARAMETER PDCEmulator
    The hostname of PDC Emulator. This machine will sync time from the chosen external NTP source.

.PARAMETER DCControllers
    The list of Domain Controllers except the PDC Emulator. These machines will use W32Time service to sync time across the domain.

#>
param(
    [parameter(Mandatory=$true)]
    [System.String] $NTPSource,

    [parameter(Mandatory=$true)]
    [System.String] $PDCEmulator,

    [parameter(Mandatory=$true)]
    [System.String[]] $DCControllers
)
begin {
$TranscriptPath = "C:\temp\ConfigureNTP_$(Get-Date -Format yyyy-MM-dd-HH-mm).log"
Start-Transcript -Path $TranscriptPath
Write-Host -ForegroundColor Yellow "Script started: "(Get-Date -Format "dddd MM/dd/yyyy HH:mm")
#Variables
[int]$StartTimer = (Get-Date).Second

#Functions
Function Configure-DomainController ($DomainController) {
    Write-Host -ForegroundColor Yellow "Updating $DomainController.."
    try {
        #Connect to a Domain Controller and configure NTP
        $s = New-PSSession -ComputerName $DomainController
        Invoke-Command -Session $s -ScriptBlock {w32tm /config /syncfromflags:DOMHIER /update}
        Invoke-Command -Session $s -ScriptBlock {w32tm /resync /nowait}
        Start-Sleep -Seconds 5
        #Restart W32Time service (net stop w32time && net start w32time)
        Invoke-Command -Session $s -ScriptBlock {Restart-Service -Name W32Time}
        Write-Host -ForegroundColor Green "Updated $DomainController successfully."
        Remove-PSSession $s;     
    }
    catch {
        Write-Host -ForegroundColor Red "Unable to update $DomainController."
        Write-Error -Message "$_" -ErrorAction Continue
        return;
    }
}
Write-Warning "Would you like to update NTP settings for the following Domain Controllers:`n$PDCEmulator,$DCControllers" -WarningAction Inquire
}
process {
#Configure the PDC Emulator
Write-Host -ForegroundColor Yellow "Updating $PDCEmulator.."
try {
    #Connect to the PDCEmulator and configure NTP
    $s = New-PSSession -ComputerName $PDCEmulator
    Invoke-Command -Session $s -ScriptBlock {w32tm /config /manualpeerlist:$NTPSource /syncfromflags:manual /reliable:yes /update}
    Invoke-Command -Session $s -ScriptBlock {w32tm /resync /rediscover}
    Start-Sleep -Seconds 5
    #Restart W32Time service (net stop w32time && net start w32time)
    Invoke-Command -Session $s -ScriptBlock {Restart-Service -Name W32Time}
    Write-Host -ForegroundColor Green "Updated $PDCEmulator successfully."
    Remove-PSSession $s;     
}
catch {
    Write-Host -ForegroundColor Red "Unable to update $PDCEmulator."
    Write-Error -Message "$_" -ErrorAction Stop
    return;
}
#Freeze time
Start-Sleep -Seconds 8

#Configure Domain Controllers
ForEach ($DCController in $DCControllers) {
    Configure-DomainController -DomainController $DCController
}
}
end {
Write-Host -ForegroundColor Yellow "Script ended: "(Get-Date -Format "dddd MM/dd/yyyy HH:mm")
[int]$EndTimer = (Get-Date).Second
Write-Host -ForegroundColor Yellow "Script completed in $([Math]::Abs($StartTimer - $EndTimer)) seconds."
Stop-Transcript
}
