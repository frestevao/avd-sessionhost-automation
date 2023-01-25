<#
.DESCRIPTION

    This script is used in the AVD Pipeline to delete the computer accounts
    The ADDS computer accoutns are deleted to grant that the domainJoin extension deployment succeed
    by avoiding duplicated names in the specified organizational unity.

.PARAMETER ouPath
    
    This is the path where the computer accounts of the AVD Environment are stored

.PARAMETER userName

    Username that has permission to delete the computer accounts in the ADDS, the user should be like DOMAINNAME\USERNAME

.PARAMETER kvName

    Parameter used to store the keyVault the contains the password of the userName parameter

.PARAMETER secretName

    Parameter used to store the password of the userName in the kvName

.PARAMETER subscriptionKeyVault

    Parameter used to store the subscription name where the keyVault is allocated

.PARAMETER domainControllerName

    Parameter used to store the name of the domain controller in the Azure network

.Example 
    ./deleteAdComputerAccount   -ouPath <OU=FSLOGIX,OU=AZURE-VIRTUAL-DESKTOP,OU=COMPUTERS,OU=ORGANIZATION,DC=myDomain,DC=com> `
                                -userName <DOMAINNAME\USER> `
                                -kvName <myKeyVault> `
                                -secretName <mySecretName> `
                                -subscriptionKeyVault <subscriptionKeyVault> `
                                -domainControllerName <domainControllerName> 
.NOTES
    
    Version: 1
    Author: Estevão França
    Date: 12/15/2022
    Version Note: This initial version only deletes the computer accounts and tracks the script actions in the logFileName variable
#>

param
(
    [parameter(Mandatory=$true,HelpMessage="Path where the AVD computer accounts are stored")]
    [string]$ouPath,
    
    [parameter(Mandatory=$true,HelpMessage="User that has permission to delete the computer accounts, the value should be DOMAIN\USERNAME")]
    [string]$userName,
    
    [parameter(Mandatory=$true,HelpMessage="Name of the keyVault that contains the password of the user that will delete the computer accounts")]
    [string]$kvName,
    
    [parameter(Mandatory=$true,HelpMessage="Name of the secret where the user passwrod is stored")]
    [string]$secretName,
    
    [parameter(Mandatory=$true,HelpMessage="subscriptionid where the keyVault is stored")]
    [string]$subscriptionKeyVault,

    [parameter(Mandatory=$true,HelpMessage="Specify the name of the domain controller")]
    [string]$domainControllerName
)

#Persistent parameter
$path = 'c:\azureDevOpsLogs' #Path used to store the file logs
$logFileName = "automationLogs_" + (Get-Date -Format 'MMddyyyy') + ".txt"

$null = Set-Location -Path 'c:\'
$testPath = Test-Path -Path $path

#Functions section
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
    $null = Set-AzContext -Subscription $subscriptionKeyVault
    logState -state "INFO" -logMessage "Subscription selected with success"
}
catch
{
    powershellLogging -codeSection "Selecting azure Subscription"
}

#Generating credentials
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Generating credentials ..."
logState -state "INFO" -logMessage "Generating the credentials"

try
{
    $credential = New-Object System.Management.Automation.PSCredential($userName, (Get-AzKeyVaultSecret -VaultName $kvName -Name $secretName).SecretValue)
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Validating credentials..."
    logState -state "INFO" -logMessage "Validating credentials..."
    if($null -ne $credential)
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Credentials succefully generated!"
        logState -state "INFO" -logMessage "Credentials succefully generated!"
    }
    else
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [ERROR] Fatal error! Not able to generate credentials"
        logState -state "ERROR" -logMessage "Fatal error! Not able to generate credentials"
        logState -state "ERROR" -logMessage "Script will be closed"
        
        exit
    }
}
catch
{
    powershellLogging -codeSection "Generating ADDS credentials"
}

#Checking ouPath
if($null -eq $ouPath)
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [ERROR] Not able to identify the OUPath!!"
    logState -state "ERROR" -logMessage "Not able to identify the OUPath!!"
    exit
}
else
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] OU Identified, distinguished name is" $ouPath
    logState -state "INFO" -logMessage "OU Identified, distinguished name is" $ouPath
}

#Getttin computer accounts list
try
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Getting ADDS computer accounts"
    logState -state "INFO" -logMessage "Getting ADDS computer accounts"

    $adComputers = Get-ADComputer   -Credential $credential `
                                    -SearchBase $ouPath `
                                    -Filter * `
                                    -ErrorAction Stop
}
catch
{
    powershellLogging -codeSection "Getting ADDS Computer Account Details"
}

if($null -eq $adComputers)
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [ERROR] Specified OU does not contains computer accounts"
    logState -state "ERROR" -logMessage "Specified OU does not contains computer accounts"
    exit 
}
else
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] OU contains" $adComputers.Count "computer accounts"
    logState -state "INFO" -logMessage "OU contains" $adComputers.Count "computer accounts"
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [WARNING] Starting the computer account object purge..."
    logState -state "WARNING" -logMessage "Starting the computer account object purge..."

    foreach($computerAccount in $adComputers)
    {
        try
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [WARNING] Deleting computer Account" $computerAccount.name
            logState -state "WARNING" -logMessage "[WARNING] Deleting computer Account" $computerAccount.name

            Remove-AdObject -Identity $computerAccount.ObjectGUID.Guid `
                            -Credential $credential `
                            -Server $domainControllerName `
                            -Confirm:$false `
                            -Recursive `
                            -ErrorAction Stop
                            
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [WARNING] Account deleted!"
            logState -state "WARNING" -logMessage "Account deleted"
        }
        catch
        {
            powershellLogging -codeSection "Deleting ADDS Computer Accounts"
        }
    }

    #Validating deletion
    $adComputers = Get-ADComputer -Credential $credential -SearchBase $ouPath -Filter *
    
    if($null -ne $adComputers)
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [ERROR] FATAL ERROR!"
        logState -state "ERROR" -logMessage "Fatal error while deleting the computer accounts!"
    }
    else
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO] Accounts succefully deleted!"
        logState -state "INFO" -logMessage "Accounts succefully deleted!"

        #Forcing ADDS sincronization
        #Trying to estabilish communication with the RPC server
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO] Trying to estabilish communication with the RPC Server to Force the sincronization!"
        logState -state "INFO" -logMessage "Trying to estabilish communication with the RPC Server to Force the sincronization!"
        
        $dcTestConnection = Test-NetConnection -ComputerName $domainControllerName -Port 135 -InformationLevel Detailed

        if($dcTestConnection.TcpTestSucceeded -eq "True")
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO] Communication succefully estabilished!"
            logState -state "INFO" -logMessage "Communication succefully estabilished!"
            
            try
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO] trying to force the sync!"
                logState -state "INFO" -logMessage "trying to force the sync"
                
                $null = repadmin /syncall $domainControllerName dc="estevaofranca",dc="com" /d/e/a

                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO] sync realized!"
                logState -state "INFO" -logMessage "sync realized"

            }
            catch
            {
                powershellLogging -codeSection "ADDS Host Sync"
            } 
        }
        else
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [ERROR] not able to communicate with the RPC server!"
            logState -state "ERROR" -logMessage "not able to communicate with the RPC server!"
        } 
        
    }
}