<#
.DESCRIPTION

    This automation is used to create a new token to register session hosts in an existent Azure Virtual Desktop host pool.

.PARAMETER avdSubscriptionName

    This parameter contains the name of the subscription where the AVD Host pool and KeyVault is.

.PARAMETER avdHostPoolName

    This parameter contains the name of the host pool that the automation will generate a new secret.

.PARAMETER avdResourceGroupName

    This parameter contains the name of the resource group where the host pools is located.

.PARAMETER keyVaultName

    This parameter contains the name of the name of the key vault where the token Secret is.

.PARAMETER avdTokenSecret

    This parameter contains the name of the name of the secret that the token will be stored.

.Example 

    ./generateAvdTokenId.ps1    -adSubscriptionName <subscriptionName> `
                                -avdHostPoolName <name of the host pool> `
                                -avdResourceGroupName <name of the resource group> `
                                -keyVaultName <name of the key vault> `
                                -avdTokenSecret <name of the secret that will store the secret>
.NOTES

    Version: 1.0
    Author: Estevão França
    Date: 12/16/2022
    Version Notes: This version stores the token as a secret in the specified keyvault. The keyVault & Secret used in this automation
    needs to be the same defined in the ARM Template parameters reference.
#>

#Parameters section
param(
    [parameter(Mandatory=$true,HelpMessage="Subscription where the AVD Host pool and KeyVault is")]
    [string]$avdSubscriptionName,

    [parameter(Mandatory=$true,HelpMessage="Host pool that the automation will generate a new secret")]
    [string]$avdHostPoolName,

    [parameter(Mandatory=$true,HelpMessage="Resource group where the host pools is")]
    [string]$avdResourceGroupName,
    
    [parameter(Mandatory=$true,HelpMessage="Name of the key vault where the token Secret is")]
    [string]$keyVaultName,

    [parameter(Mandatory=$true,HelpMessage="Name of the secret that the token will be stored")]
    [string]$avdTokenSecret
)

#Persistent parameter
$path = 'c:\azureDevOpsLogs' #Path used to store the file logs
$logFileName = "automationLogs_" + (Get-Date -Format 'MMddyyyy') + ".txt"
Write-Warning -Message "Path Already Exists, nothing to do!"
#Setting the c: as location
$null = Set-Location -Path "c:\"

#Functions Section
function powershellLogging ([string]$codeSection)
{
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " =========== "
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [ERROR]" + $codeSection >> $logFileName
    $errorMessage = $_.Exception.Message            
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [ERROR]" + "Something went wrong - $errorMessage" >> $logFileName
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [ERROR]" + $_.Exception >> $logFileName
    
    #information about where excemption was thrown
    (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [ERROR]" + $PSItem.InvocationInfo | Format-List * >> $logFileName #can also use $psItem instead of $_.
}
function logState([string]$state,[string]$logMessage)
{
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [" + $state + "] " + $logMessage >> $logFileName
}

#Checking if the logging path is available
$testPath = Test-Path -Path $path

# Checking logpath
if($testPath -eq $false)
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [WARNING] PATH USED TO STORE THE LOGS DOES NOT EXIST!"
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Creating the path"
    
    $pathCreation = New-Item -ItemType Directory $path
    
    if($pathCreation.Exists -ne $true)
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [ERROR] ERROR WHILE CREATING THE PATH!!"
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [ERROR] SCRIPT WON'T BE ABLE TO STORE THE LOGS!"
    }
    
    $null = Set-Location -Path $path
}
else
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Log path does exist"
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Setting as current path"
    $null = Set-Location -Path $path
}

#Connection on Azure
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] Selecting the Azure Subscription...."
logState -state "INFO" -logMessage "Selecting the azure subscription"
try
{
    $null = Set-AzContext -Subscription $avdSubscriptionName
    logState -state "INFO" -logMessage "Subscription selected with success"
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] Subscription selected with success"
}
catch
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [ERROR] FATAL ERROR"
    powershellLogging -codeSection "Selecting azure Subscription"
}

#Generates the token
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Generating the AVD registration token" 

try
{
    $registrationToken = New-AzWvdRegistrationInfo  -ResourceGroupName $avdResourceGroupName `
                                                    -HostPoolName $avdHostPoolName `
                                                    -ExpirationTime $((Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')) `
                                                    -ErrorAction Stop
    
    #Converts the token to a secureString
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO]token succefully generated"
    logState -state "INFO" -logMessage "token succefully generated"

    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] converting token as secred in the $keyVaultName"
    logState -state "INFO" -logMessage "converting token as secred in the $keyVaultName"
}
catch
{
    powershellLogging -codeSection "Generating Registration token"
}

try 
{
    #Converts the token to a secureString
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Converting token as Secret" 
    logState -state "INFO" -logMessage "Converting token as Secret"

    $tokenAsSecret = ConvertTo-SecureString -String $registrationToken.Token -AsPlainText -Force

    #Importing the token as a secret to the keyVault
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " [INFO] Storing token as a secret in the Azure KeyVault"
    $null = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $avdTokenSecret -SecretValue $tokenAsSecret -Expires (Get-Date).AddDays(1).ToUniversalTime()     
}
catch 
{
    powershellLogging -codeSection "Generating Azure KV Secrete"
}

logState -state "INFO" -logMessage "Secret version successfully generated"