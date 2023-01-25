<#
.DESCRIPTION
    This script is responsible to deploy the VM's
.PARAMETER templateFile
    
.PARAMETER templateParametersFile
    
.PARAMETER avdResourceGroupName
    
.PARAMETER subscriptionKeyVault
    

.Example 
    ./newAzSessionHostDeployment    -templateFile <> `
                                    -templateParametersFile <> `
                                    -avdResourceGroupName <> `
                                    -subscriptionKeyVault <> 

.NOTES
    Version: 1
    Date: 12/15/2022
    Version Note: This initial version only deletes the computer accounts and tracks the script actions in the logFileName variable
#>

param
(
    [parameter(Mandatory=$true,HelpMessage="Remote path of the template file")]
    [string]$templateFile,
    
    [parameter(Mandatory=$true,HelpMessage="Remote path of the template parameters file")]
    [string]$templateParametersFile,

    [parameter(Mandatory=$true,HelpMessage="resource group where the vms will be deployed")]
    [string]$avdResourceGroupName,    
    
    [parameter(Mandatory=$true,HelpMessage="Subscription where the resources will be deployed")]
    [string]$subscriptionKeyVault

)

#Region Fixed Parameters
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

#Endregion

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


$deploymentName = "deploying-az-host-pool-" + (Get-Random)

try
{
    $outputs = New-AzResourceGroupDeployment `
                        -Name $deploymentName `
                        -TemplateFile $templateFile `
                        -TemplateParameterFile $templateParametersFile `
                        -ResourceGroupName $avdResourceGroupName
    
    if($outputs.ProvisioningState -ne "Succeeded")
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [ERROR] The deployment failed!" 
        logState -state "ERROR" -logMessage "The deployment failed!"
    }
}
catch
{
    powershellLogging -codeSection "Deployment"
}