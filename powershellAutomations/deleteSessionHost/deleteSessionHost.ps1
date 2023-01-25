<#
.DESCRIPTION
    
    This script is used to remove all session hosts on a specific host pool
    It also deletes the VM's container, Disks and Network Adapter.  

.PARAMETER avdHostPool

    This parameter is used to store the name of the AVD Hostpool that the automation will delete the session hosts

.PARAMETER avdResourceGroupName

    This parameter is used to store the name of the resourceGroup where the hostPool is stored

.Example 

    ./deleteSessionHost.ps1 -avdHostPoolName <hostPoolName> `
                            -avdResourceGroupName <avdResourceGroupName>
.NOTES

    Version: 1.0
    Author: Estevão França
    Date: 12/14/2022
    Version Notes: This initial version deletes the VM's based in the host pool active session hosts.

    #>

#Parameters section
param(
    [parameter(Mandatory=$true,HelpMessage="AVD HostPool where you'll delete the session hosts")]
    [string]$avdSubscriptionName,

    [parameter(Mandatory=$true,HelpMessage="AVD HostPool where you'll delete the session hosts")]
    [string]$avdHostPoolName,

    [parameter(Mandatory=$true,HelpMessage="Name of the customer")]
    [string]$avdResourceGroupName
)

#Persistent parameter
$path = 'c:\azureDevOpsLogs'#Path used to store the file logs
$logFileName = "automationLogs_" + (Get-Date -Format 'MMddyyyy') + ".txt"

$null = Set-Location -Path 'c:\'
$testPath = Test-Path -Path $path

#Checking if the logging path is available

#Code Functions

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

function deleteAzureVm($vmName)
{
    #Getting VM Details
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "Getting VM Details"
    logState -state "INFO" -logMessage "GETTING VM DETAILS"
    
    try
    {
        $vmProperties = Get-AzVm -Name $vmName
        if($null -ne $vmProperties)
        {       
            logState -state "INFO" -logMessage "AUTOMATION SUCCEFULLY COLLECTED THE VM DETAILS"
            logState -state "INFO" -logMessage "VM NAME:"  $vmProperties.Name
        }
        else
        {
            logState -state "WARNING" -logMessage "NOT ABLE TO GRAB THE VM DETAILS"
            powershellLogging -codeSection "Getting VM Details"
            return 
        }
    }
    catch
    {
        #Calling logging function
        powershellLogging -codeSection "Getting VM Details"
    }

    #Deleting Vm Container
    if ($null -ne $vmProperties)
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO] STARTING THE VM CONTAINER DELETION"
        logState -state "INFO" -logMessage "STARTING THE VM CONTAINER DELETION JOB"
                
        #Deleting vm Container
        logState -state "INFO" -logMessage "EXECUTING THE DELETE CMDLET..."
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO] EXECUTING THE DELETE CMDLET..." $vmProperties.Name

        try
        {
            $removeVm = Remove-azVm -Id $vmProperties.Id -Force
            
            #Checking vm container delete output
            if($removeVm.Status -eq "Succeeded")
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "VM SUCCEFULLY DELETED"
                logState -state "INFO" -logMessage "VM SUCCEFULLY DELETED"
            }
            else
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [ERROR]" "NOT ABLE TO DELETE THE VM CONTAINER"
                logState -state "ERROR" -logMessage "NOT ABLE TO DELETE THE VM CONTAINER"
            }
        }
        catch
        {
            #Calling logging function
            powershellLogging -codeSection "Removing VM Container"
        }
    }
    else
    {
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [ERROR]" "NOT ABLE TO DELETE VM CONTAINER!"
        #Calling logging function
        powershellLogging -codeSection "Fail to remove vm container"
        return
    }

                
    #Deleting osDisk
    try
    {
        #Getting the os disk details
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "GETTING THE OS DISK DETAILS"
        logState -state "INFO" -logMessage "GETTING THE OS DISK DETAILS"
        if($null -ne $vmProperties.StorageProfile.OsDisk.Name)
        {
            $osDiskDetails = Get-AzDisk `
                                    -DiskName $vmProperties.StorageProfile.OsDisk.Name
        }
        else
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [ERROR]" "NOT ABLE TO IDENTIFY OS DISK"
            logState -state "ERROR" -logMessage "NOT ABLE TO IDENTIFY OS DISK"
            return
        }
        #Validates the content of the variable $osDiskDetails, if the variable does not gets the osDisk content, the script fails
        if($null -ne $osDiskDetails)
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "OS DISK NAME:" $osDiskDetails.Name
            logState -state "INFO" -logMessage "OS DISK" + $osDiskDetails.Name

            #Deleting os Disk
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "STARTING THE OS DISK DELETION"
            logState -state "INFO" -logMessage "STARTING OS DISK DELETION"

            $removeOsDisk = Remove-AzDisk   `
                                    -DiskName $osDiskDetails.Name `
                                    -ResourceGroupName $osDiskDetails.ResourceGroupName `
                                    -Force
                    
            if($removeOsdisk.Status -eq "Succeeded")
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "OS DISK SUCCEFULLY DELETED!"
                logState -state "INFO" -logMessage "OS DISK SUCCEFULLY DELETED!"
            }
            else
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [ERROR]" "OS DISK NOT DELETED!"
                logState -state "ERROR" -logMessage "OS DISK NOT DELETED!"
            }
        }        
    }
    catch
    {
        #Calling logging function
        powershellLogging
    }

    #Deleting network adapter
    try
    {
        #Getting the nic details
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "GETTING NETWORK ADAPTER..."
        logState -state "INFO" -logMessage "GETTING NETWORK ADAPTER DETAILS..."

        if($null -eq $vmProperties.NetworkProfile.NetworkInterfaces.id.Split('/')[8])
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [ERROR]" "not able to identify the network adapter name!"
            logState -state "ERROR" -logMessage "Not able to identify the network adapter name"
            return
        }
        else
        {
            $networkAdapterDetails = Get-AzNetworkInterface -Name $vmProperties.NetworkProfile.NetworkInterfaces.id.Split('/')[8]
        }
        if($null -or " " -ne $networkAdapterDetails)
        {
            #Deleting network adapter
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "STARTING THE DELETION JOB OF THE NIC: " $networkAdapterDetails.Name
            logState -state "INFO" -logMessage "STARTING THE DELETION JOB OF THE NIC: " + $networkAdapterDetails.Name

            try
            {
                $null = Remove-AzNetworkInterface   -Name $networkAdapterDetails.Name `
                                                    -ResourceGroupName $networkAdapterDetails.ResourceGroupName `
                                                    -Force
                
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "NETWORK ADAPTER SUCCEFULLY DELETED!"
                logState -state "INFO" -logMessage "NETWORK ADAPTER SUCCEFULLY DELETED!"
            }
            catch
            {
                #Calling logging function
                powershellLogging
            }
        }
    }
    catch
    {
        #Calling logging function
        powershellLogging -codeSection "Networking section"
    }
}

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
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] Subscription selected with success"
    logState -state "INFO" -logMessage "Subscription selected with success"
}
catch
{
    powershellLogging -codeSection "Selecting azure Subscription"
}


#Getting the Session Hosts
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "Getting Session hosts in the provided host pool"
logState -state "INFO" -logMessage "Getting Session hosts in the provided host pool"
try
{
    $sessionHostPool = Get-AzWvdSessionHost -ResourceGroupName $avdResourceGroupName `
                                            -HostPoolName $avdHostPoolName
}
catch
{
    #Calling logging function
    powershellLogging -codeSection "Getting AVD Session Hosts"
}

if($null -eq $sessionHostPool)
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [WARNING]" "Not able to identify session hosts on the provided host pool"
    logState -state "WARNING" -logMessage "Not able to identify session hosts on the provided host pool"
}
else 
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Provided host pool contains" $sessionHostPool.Name.count "Session hosts"
    logState -state "INFO" -logMessage " = [INFO] Provided host pool contains " + $sessionHostPool.Name.count + " Session hosts"
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Starting the Deletion job...."
    logState -state "INFO" -logMessage "Starting the Deletion job"
    
    foreach($sessionHost in $sessionHostPool)
    {
        #Ajusting the computer name pattern
        $sessionHostName = $sessionHost.Name.Split('/')[1]
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Starting the analyses in the session host:" $sessionHostName
        
        logState -state "INFO" -logMessage "Starting the analyses in the session host: " + $sessionHostName

        #Checking if session host have active connections
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Checking if the session host has active sessions"

        logState -state "INFO" -logMessage "Checking if the session host has active sessions"

        try
        {
            $avdUserSessions = Get-AzWvdUserSession -ResourceGroupName $avdResourceGroupName `
                                            -HostPoolName $avdHostPoolName `
                                            -SessionHostName $sessionHostName
        }
        catch
        {
            #Calling logging function
            powershellLogging -codeSection "Checking if the session host has active sessions"
        }

        if($null -eq $avdUserSessions)
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "The Session Host does not have any active connection"
            logState -state "INFO" -logMessage "The Session Host does not have any active connection"

            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "Deleting the session host"
            logState -state "INFO" -logMessage "Removing Session Host Register from the AVD Pool"
            
            #Removing session host
            try
            {
                $null = Remove-AzWvdSessionHost -ResourceGroupName $avdResourceGroupName `
                                                -HostPoolName $avdHostPoolName `
                                                -Name $sessionHostName `
                                                -Force
            }
            catch
            {
                #Calling logging function
                powershellLogging -codeSection "The Session Host does not have any active connection"
            }
            
            logState -state "INFO" -logMessage "Session host removed"
            
            #Deleting the computer on Azure
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" "Starting the computer deletion"

            logState -state "INFO" -logMessage "Starting the computer deletion"

            #Getting the computer details
            
            $vmName = $sessionHostName.Split('.')[0]
            
            deleteAzureVm -vmName $vmName
        }
        else
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Session host contains active session"
            logState -state "INFO" -logMessage "Session host contains active session"

            #Forcing user logoff
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " [INFO] Number of connections" $avdUserSessions.Count
            logState -state "INFO" -logMessage "Number of connections" $avdUserSessions.Count
            
            foreach($activeSession in $avdUserSessions)
            {
                if($activeSession.SessionState -eq "Active")
                {
                    #Forcing user logoff
                    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Forcing the user logoff"
                    try
                    {
                        $null = Remove-AzWvdUserSession -HostPoolName $avdHostPoolName `
                                                -id $activeSession.Id.Split('/')[12] `
                                                -ResourceGroupName $avdResourceGroupName `
                                                -SessionHostName $sessionHostName `
                                                -Force 
                    }
                    catch
                    {
                        #Calling logging function
                        powershellLogging -codeSection "Forcing the user logoff"
                    }
                }
            }
            #Removing Session host from the avd pool
            
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Removing session host from the host pool"
            logState -state "INFO" -logMessage "Removing session host from the host pool"
            
            try
            {
                $null = Remove-AzWvdSessionHost -ResourceGroupName $avdResourceGroupName `
                                        -HostPoolName $avdHostPoolName `
                                        -Name $sessionHostName `
                                        -Force
            }
            catch
            {
                #Calling logging function
                powershellLogging -codeSection "Removing the session host register"
            }
            
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" " The Session Host does not have any active connection"
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [INFO]" + " The Session Host does not have any active connection" >> $logFileName
            
            #Deleting the computer on Azure
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [INFO]" " Starting the computer deletion"
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [INFO]" + " Starting the computer deletion" >> $logFileName

            #Getting the computer details
            $vmName = $sessionHostName.Split('.')[0]
            
            deleteAzureVm -vmName $vmName
        }
        
        $null = "=============" >> $logFileName

    }
}