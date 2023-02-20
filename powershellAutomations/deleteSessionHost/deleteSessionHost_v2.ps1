<#
.DESCRIPTION
    This script is used to delete all session hosts on a specific host pool
.PARAMETER avdHostPool
    This parameter is used to store the name of the AVD Hostpool that the automation will delete the session hosts
.PARAMETER avdResourceGroupName
    This parameter is used to store the name of the resourceGroup where the hostPool is stored
.Example 
    ./deleteSessionHost.ps1 -avdHostPoolName <hostPoolName> `
                            -avdResourceGroupName <avdResourceGroupName>
.NOTES
    Version: 2
    Date: 08/02/2023
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
$logFileName = "log_deleting_session_host" + (Get-Date -Format 'MMddyyyy') + ".txt"

$null = Set-Location -Path 'c:\'
$testPath = Test-Path -Path $path

#Checking if the logging path is available

#Code Functions

function powershellLogging ([string]$codeSection)
{
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " =========== "
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + $codeSection >> $logFileName
    $errorMessage = $_.Exception.Message            
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Something went wrong - $errorMessage" >> $logFileName
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + $_.Exception >> $logFileName
    
    #information about where excemption was thrown
    (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + $PSItem.InvocationInfo | Format-List * >> $logFileName #can also use $psItem instead of $_.
}

$deleteAzureVm =
{
    param([string] $vmName)

    #Getting VM Details
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Getting VM Details"
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Getting VM Details!" >> $logFileName
    try
    {
        $vmProperties = Get-AzVm -Name $vmName
        if($null -ne $vmProperties)
        {       
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Automation managed to grab the vm details" >> $logFileName
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "vm name:" + $vmProperties.Name >> $logFileName
        }
        else
        {
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "not able to get the vm details..." >> $logFileName
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
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Starting the deletion of the VM on Azure"
        $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Starting the deletion of the VM on Azure" >> $logFileName
                
        #Deleting vm Container
        $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Deleting vm container" >> $logFileName
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Deleting vm" $vmProperties.Name

        try
        {
            Write-Host "Starting deletion..."
            $removeVm = Remove-azVm -Id $vmProperties.Id -Force
            
            #Checking vm container delete output
            if($removeVm.Status -eq "Succeeded")
            {
                $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "VM Succefully deleted" >> $logFileName   
            }
            else
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Not Able to delete the VM!!"
                $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Error while deleting the vm" >> $logFileName                
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
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  "FATAL ERROR!"
        #Calling logging function
        powershellLogging -codeSection "Fail to remove vm container"
    }

                
    #Deleting osDisk
    try
    {
        #Getting the os disk details
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Getting the os disk..."
        $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Getting the os disk details..." >> $logFileName        
        
        $osDiskDetails = Get-AzDisk `
                                -DiskName $vmProperties.StorageProfile.OsDisk.Name

        #Validates the content of the variable $osDiskDetails, if the variable does not gets the osDisk content, the script fails
        if($null -ne $osDiskDetails)
        {
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "os disk name " + $osDiskDetails.Name >> $logFileName        

            #Deleting os Disk
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Starting the disk delete operation..." >> $logFileName        
            $removeOsDisk = Remove-AzDisk   `
                                    -DiskName $osDiskDetails.Name `
                                    -ResourceGroupName $osDiskDetails.ResourceGroupName `
                                    -Force
                    
            if($removeOsdisk.Status -eq "Succeeded")
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Os Disk Succefully deleted"
                $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "OsDisk Succefully deleted" >> $logFileName
            }
            else
            {
                Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Error while deleting the os Disk"
                $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Errow while deleting the osDisk" >> $logFileName
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
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Getting network adapter..."
        $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Getting network adapter details" >> $logFileName
        $networkAdapterDetails = Get-AzNetworkInterface -Name $vmProperties.NetworkProfile.NetworkInterfaces.id.Split('/')[8]
        if($null -or " " -ne $networkAdapterDetails)
        {
            #Deleting network adapter
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString()  " = Deleting NIC:" $networkAdapterDetails.Name
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "network adapter name: " + $networkAdapterDetails.Name >> $logFileName
            try
            {
                $null = Remove-AzNetworkInterface   -Name $networkAdapterDetails.Name `
                                                    -ResourceGroupName $networkAdapterDetails.ResourceGroupName `
                                                    -Force
                
                $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Network adapter deleted" >> $logFileName
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
    Write-Warning -Message "Path does not exist!"
    Write-Warning -Message "Creating the path"
    try 
    {
        $pathCreation = New-Item -ItemType Directory $path 
    }
    catch 
    {
        $errorMessage = $_.Exception.Message
        Write-Output "Something went wrong - $errorMessage"
    }
    

    if($pathCreation.Exists -ne $true)
    {
        Write-Error -Message "Error while creating the path!!"
        Write-Error -Message "Fatal error"
    }

    $null = Set-Location -Path $path
}
else
{
    Write-Warning -Message "Path Already Exists, nothing to do!"
    Write-Host "Setting the path..."
    $null = Set-Location -Path $path
}

#Setting the subscription
try
{
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "selecting the provided subscription" + $avdSubscriptionName >> $logFileName
    $null = Set-AzContext -Subscription $avdSubscriptionName
}
catch
{
    #Calling logging function
    powershellLogging -codeSection "Setting Azure Subscription"
}

#Getting the Session Hosts
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Getting Session hosts in the provided host pool" -ForegroundColor Cyan
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
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Not able to identify session hosts on the provided host pool"
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Not able to identify session hosts on the provided host pool" >> $logFileName
}
else 
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Provided host pool contains" $sessionHostPool.Name.count "Session hosts"
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Starting the Deletion...."
    
    #Clean Jobs list
    Get-Job | Remove-Job 

    foreach($sessionHost in $sessionHostPool)
    {
        #Ajusting the computer name pattern
        $sessionHostName = $sessionHost.Name.Split('/')[1]
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Starting the analyses in the session host:" $sessionHostName
        
        $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Checking the session host:" + $sessionHostName >> $logFileName

        #Checking if session host have active connections
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Checking if the session host has active sessions"

        $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Checking if the session host has active sessions" + $sessionHostName >> $logFileName

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
            Write-Host  "The Session Host does not have any active connection"
        
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "The Session Host does not have any active connection" >> $logFileName

            Write-Host  "Deleting the session host"
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Removing Session Host Register from the AVD Pool" >> $logFileName

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
            
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Session host removed" >> $logFileName
            
            #Deleting the computer on Azure
            Write-Host  "Starting the computer deletion"

            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Starting the computer deletion" >> $logFileName

            #Getting the computer details
            
            $vmName = $sessionHostName.Split('.')[0]
            
            Start-Job -ScriptBlock $deleteAzureVm -ArgumentList $vmName
        }
        else
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Session host contains active session"
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Session host contains active session" >> $logFileName

            #Sending notification to the users
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Number of connections " + $avdUserSessions.Count >> $logFileName
            
            foreach($activeSession in $avdUserSessions)
            {
                if($activeSession.SessionState -eq "Active")
                {
                    #Forcing user logoff
                    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Forcing the user logoff"
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
            
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Deleting the session host"
            
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Removing session host from the host pool" >> $logFileName
            
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
            
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = The Session Host does not have any active connection"
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "The Session Host does not have any active connection" >> $logFileName
            
            #Deleting the computer on Azure
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = Starting the computer deletion"
            $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "Starting the computer deletion" >> $logFileName

            #Getting the computer details
            $vmName = $sessionHostName.Split('.')[0]
            
            Start-Job -ScriptBlock $deleteAzureVm -ArgumentList $vmName
        }
    }

    #Wait for all Jobs to finish
    Get-Job | Wait-Job

    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() " = All Jobs done! Bye..." -ForegroundColor Cyan
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm').ToString() + " = " + "All Jobs done! Bye..." >> $logFileName
}