#____________________________________________________________
# https://www.techthoughts.info/powershell-scripts/
#____________________________________________________________

#region links

#About Execution Policies
#https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-6

#About Scripts
#https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_scripts?view=powershell-6

#endregion

PowerShell's execution policy 
    security feature 
    controls the conditions under which PowerShell can run scripts.
    A safety net to prevent the execution of malicious scripts,
    Not a foolproof security measure (a determined user can bypass it).  
    Just a first line of defense.   

Here's a breakdown of key aspects:

What it does:

The execution policy 
    determines whether you can run scripts at all,
    if so, under what conditions.
    Makes it harder for untrusted scripts to run accidentally or unknowingly.   

Different Execution Policies:

PowerShell defines several execution policies, each with different levels of restrictiveness:   

  Restricted (Default):  
      No scripts can be run.  
      Most restrictive policy.  
      You can still run individual commands interactively, but not scripts.   

  AllSigned: 
      All scripts must be signed by a trusted publisher.
      Most secure policy 
          but can be inconvenient if you're working with scripts from various sources.   

  RemoteSigned: 
      Scripts downloaded from the internet 
          must be signed by a trusted publisher.  
        Locally created scripts can run without a signature. 
        This is a common and often recommended balance between security and usability.   

Bypass:  
    No restrictions. 
    All scripts can run without a signature.  
    Use this only if you 
        completely trust all the scripts you're running
        understand the security implications.  
    It's generally not recommended for regular use.

  Unrestricted:  
      All scripts can run, even unsigned ones.  
      Similar to Bypass, 
          but it also warns you before running unsigned scripts.  
        Less restrictive than Bypass, 
            but still not recommended for general use unless you have a very specific reason.   




#region running scripts

#get the execution policy of all scopes in the order of precedence
Get-ExecutionPolicy -List

#change execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#Set-ExecutionPolicy <PolicyName> -Scope <Scope> -Force

#unblock a script downloaded from the internet after you have read and understood the code
Unblock-File -Path .\drive_warn.ps1

#run a local script
.\drive_warn.ps1

#run a local script in the current scope
. .\drive_warn.ps1

#endregion

#region script example

param (
    [Parameter(Mandatory = $true)]
    [string]
    $Drive
)

if ($PSVersionTable.Platform -eq 'Unix') {
    $logPath = '/tmp'
}
else {
    $logPath = 'C:\Logs' #log path location
}

#need linux path

$logFile = "$logPath\driveCheck.log" #log file

#verify if log directory path is present. if not, create it.
try {
    if (-not (Test-Path -Path $logPath -ErrorAction Stop )) {
        # Output directory not found. Creating...
        New-Item -ItemType Directory -Path $logPath -ErrorAction Stop | Out-Null
        New-Item -ItemType File -Path $logFile -ErrorAction Stop | Out-Null
    }
}
catch {
    throw
}

Add-Content -Path $logFile -Value "[INFO] Running $PSCommandPath"

#verify that the required Telegram module is installed.
if (-not (Get-Module -ListAvailable -Name PoshGram)) {
    Add-Content -Path $logFile -Value '[INFO] PoshGram not installed.'
    throw
}
else {
    Add-Content -Path $logFile -Value '[INFO] PoshGram module verified.'
}

#get hard drive volume information and free space
try {
    if ($PSVersionTable.Platform -eq 'Unix') {
        $volume = Get-PSDrive -Name $Drive -ErrorAction Stop
        #verify volume actually exists
        if ($volume) {
            $total = $volume.Free + $volume.Used
            $percentFree = [int](($volume.Free / $total) * 100)
            Add-Content -Path $logFile -Value "[INFO] Percent Free: $percentFree%"
        }
        else {
            Add-Content -Path $logFile -Value "[ERROR] $Drive was not found."
            throw
        }
    }
    else {
        $volume = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -eq $Drive }
        #verify volume actually exists
        if ($volume) {
            $total = $volume.Size
            $percentFree = [int](($volume.SizeRemaining / $total) * 100)
            Add-Content -Path $logFile -Value "[INFO] Percent Free: $percentFree%"
        }
        else {
            Add-Content -Path $logFile -Value "[ERROR] $Drive was not found."
            throw
        }
    }
}
catch {
    Add-Content -Path $logFile -Value '[ERROR] Unable to retrieve volume information:'
    Add-Content -Path $logFile -Value $_
    throw
}

#evaluate if a message needs to be sent if the drive is below 20GB free space
if ($percentFree -le 20) {

    try {
        Import-Module PoshGram -ErrorAction Stop
        Add-Content -Path $logFile -Value '[INFO] PoshGram imported successfully.'
    }
    catch {
        Add-Content -Path $logFile -Value '[ERROR] PoshGram could not be imported:'
        Add-Content -Path $logFile -Value $_
        throw
    }

    Add-Content -Path $logFile -Value '[INFO] Sending Telegram notification'

    $messageSplat = @{
        BotToken    = "#########:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        ChatID      = "-#########"
        Message     = "[LOW SPACE] Drive at: $percentFree%"
        ErrorAction = 'Stop'
    }

    try {
        Send-TelegramTextMessage @messageSplat
        Add-Content -Path $logFile -Value '[INFO] Message sent successfully'
    }
    catch {
        Add-Content -Path $logFile -Value '[ERROR] Error encountered sending message:'
        Add-Content -Path $logFile -Value $_
        throw
    }

}

#endregion
