<#
.DESCRIPTION

    This automation configures all VM's from the specified resource group in a Log Analytics Workspace
    The LAWS is used as a requirement for the Azure Application insights.

.PARAMETER workspaceKey
    
    The key used in the 

.PARAMETER workspaceId

    Parameter used to store the keyVault the contains the password of the userName parameter

.PARAMETER subscriptionLaws

    Parameter used to store the subscription name where the keyVault is allocated

.PARAMETER avdVmsResourceGroup
    
    Parameter used to store the name of the domain controller in the Azure network

.Example 
    ./deleteAdComputerAccount   -subscriptionLaws `
                                -workspaceId `
                                -workspaceKey `
                                -avdVmsResourceGroup

.NOTES

    Version: 1.0
    Author: Estevão França
    Date: 01/21/2023
    Version Note: This automation configures the log analytics in all VM's in the specified resource Group.
#>

param
(
    [parameter(Mandatory=$true,HelpMessage="subscriptionid where the laws is stored")]
    [string]$subscriptionLaws,

    [parameter(Mandatory=$true,HelpMessage="resource group used to store the VM's")]
    [string]$avdVmsResourceGroup,

    [parameter(Mandatory=$true,HelpMessage="Id of the Workspace used in the Insights")]
    [string]$workspaceId,

    [parameter(Mandatory=$true,HelpMessage="Key of the workspace used in the insights")]
    [string]$workspaceKey
)

#Region Persistent parameter
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
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] Selecting the Azure Subscription...." >> $logFileName
logState -state "INFO" -logMessage "Selecting the azure subscription"
try
{
    $null = Set-AzContext -Subscription $subscriptionLaws
    logState -state "INFO" -logMessage "Subscription selected with success"
}
catch
{
    powershellLogging -codeSection "Selecting azure Subscription"
}

$PublicSettings = @{"workspaceId" = $workspaceId}
$ProtectedSettings = @{"workspaceKey" = $workspaceKey}

try
{#Getting Vm's
    $vmPool = Get-AzVm -ResourceGroupName $avdVmsResourceGroup
}
catch
{
    powershellLogging -codeSection "Getting VM's"
}

foreach($vm in $vmPool)
{
    #Notifications
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] Enabling vm insights for AVD ...."
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] VM Name...." $vm.Name
    logState -state "INFO" -logMessage "Enabling vm insights for AVD"
    logState -state "INFO" -logMessage "VM Name" + $vm.Name
    try
    {
        $deployAgent = Set-AzVMExtension -ExtensionName "MicrosoftMonitoringAgent" `
                                            -ResourceGroupName $vm.ResourceGroupName `
                                            -VMName $vm.Name `
                                            -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
                                            -ExtensionType "MicrosoftMonitoringAgent" `
                                            -TypeHandlerVersion 1.0 `
                                            -Settings $PublicSettings `
                                            -ProtectedSettings $ProtectedSettings `
                                            -Location $vm.Location

        if($deployAgent.IsSuccessStatusCode -ne "True")
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [ERROR] Not able to configure de workspace  in the VM" $vm.Name
            logState -state "ERROR" -logMessage "Not able to configure de workspace  in the VM" + $vm.Name
        }
        else
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] LAWS Succefully enabled in the VM " $vm.Name
            logState -state "INFO" -logMessage "LAWS Succefully enabled in the VM " + $vm.Name
        }    
    }
    catch
    {
        powershellLogging -codeSection "ENABLING LAWS"
    }

}

