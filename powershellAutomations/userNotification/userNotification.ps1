<#
.DESCRIPTION
    This script is used to send a notification to the active sections in the AVD session host

.PARAMETER avdSubscriptionName
    Name of the subscription where the resources are stored/billed.

.PARAMETER avdHostPool
    This parameter is used to store the name of the AVD Hostpool that the automation will delete the session hosts

.PARAMETER avdResourceGroupName
    This parameter is used to store the name of the resourceGroup where the hostPool is stored

.Example 
    ./avdUserNotification.ps1   -avdHostPoolName <hostPoolName> `
                                -avdResourceGroupName <avdResourceGroupName> `
                                -avdSubscriptionName <avdSubscriptionName or SubscriptionId>

.NOTES
    Version: 1.0
    Author: Estevão França
    Date: 12/14/2022
#>

#Parameters section
param(
    [parameter(Mandatory=$true,HelpMessage="Subscription where the AVD HostPool is")]
    [string]$avdSubscriptionName,

    [parameter(Mandatory=$true,HelpMessage="AVD HostPool where you'll delete the session hosts")]
    [string]$avdHostPoolName,

    [parameter(Mandatory=$true,HelpMessage="Name of the resource group where the avd host pool is stored")]
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
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = " + $codeSection >> $logFileName
    $errorMessage = $_.Exception.Message            
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = " + "Something went wrong - $errorMessage" >> $logFileName
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = " + $_.Exception >> $logFileName
    
    #information about where excemption was thrown
    (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = " + $PSItem.InvocationInfo | Format-List * >> $logFileName #can also use $psItem instead of $_.
}
function logState([string]$state,[string]$logMessage)
{
    $null = (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() + " = [" + $state + "] " + $logMessage >> $logFileName
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

#Setting the subscription
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " =  [INFO] Selecting the Azure Subscription...."
logState -state "INFO" -logMessage "Selecting the azure subscription"

try
{
    $null = Set-AzContext -Subscription $avdSubscriptionName
    logState -state "INFO" -logMessage "Subscription selected with success"
}
catch
{
    powershellLogging -codeSection "Selecting azure Subscription"
}

#Getting the Session Hosts
Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Getting Session hosts in the provided host pool" 
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
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Not able to identify session hosts on the provided host pool"
    logState -state "INFO" -logMessage "Not able to identify session hosts on the provided host pool"
}
else 
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Provided host pool contains" $sessionHostPool.Name.count "Session hosts"
    logState -state "INFO" -logMessage "Provided host pool contains" $sessionHostPool.Name.count "Session hosts" 
    
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Starting the analyses of active sessions..."
    logState -state "INFO" -logMessage "Starting the analyses of active sessions"

    foreach($sessionHost in $sessionHostPool)
    {
        ####
        #Ajusting the computer name pattern
        $sessionHostName = $sessionHost.Name.Split('/')[1]
        
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Starting the analyses in the session host:" $sessionHostName
        logState -state "INFO" -logMessage "Starting the analyses in the session host:" $sessionHostName

        #Enabling Drain Mode
        try
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Enabling drain mode to avoid new connections in the session host"
            logState -state "INFO" -logMessage "Enabling drain mode to avoid new connections in the session host"

            $null = Update-AzWvdSessionHost -ResourceGroupName $avdResourceGroupName `
                                            -HostPoolName $avdHostPoolName `
                                            -Name $sessionHostName `
                                            -AllowNewSession:$False
        
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] drain mode succefully enabled"
            logState -state "INFO" -logMessage "drain mode succefully enabled"
        }
        catch
        {
            #Calling logging function
            powershellLogging -codeSection "Enabling AVD DrainMode"
        }

        #Checking if session host have active connections
        Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Looking for active sessions" 
        logState -state "INFO" -logMessage "Looking for active sessions"
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
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] session host doesn't have any active connection" 
            logState -state "INFO" -logMessage "session host doesn't have any active connection"
        }
        else
        {
            Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString()  " = [WARNING] Session host contains active session"
            logState -state "WARNING" -logMessage "Session host contains active session"
            logState -state "WARNING" -logMessage "Number of connections " $avdUserSessions.Count
            
            #Sending notification to the users
            foreach($activeSession in $avdUserSessions)
            {
                if($activeSession.SessionState -eq "Active")
                {
                    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [WARNING] The user Session is active!"
                    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [WARNING] Sending an alert to the user"
                    
                    logState -state "WARNING" -logMessage "Sending notification to the active users"

                    #Generating user details variables
                    $userName = $activeSession.ActiveDirectoryUserName.Split('\')[1]
                    
                    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] logged user name" $userName 
                    logState -state "INFO" -logMessage "Logged user name: " $userName  $logFileName

                    [string]$messageTitle = "ALERT! Server Mainatence"
                    [string]$messageBody = "Dear user, " + $userName + " Your session Will be deactivated in 5   minutes, please save your work"
                        
                    #Sending message to the user
                    try
                    {
                        $null = Send-AzWvdUserSessionMessage    -ResourceGroupName $avdResourceGroupName `
                                                                -HostPoolName $avdHostPoolName `
                                                                -SessionHostName $sessionHostName `
                                                                -UserSessionId $activeSession.Id.Split('/')[12] `
                                                                -MessageTitle $messageTitle `
                                                                -MessageBody  $messageBody
                        
                        logState -state "INFO" -logMessage "Alert sent!" 
                    }
                    catch
                    {
                        #Calling logging function
                        powershellLogging -codeSection "Sending message to the user"
                    }
                }
                else
                {
                    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] session not activated"
                    logState -state "INFO" -logMessage "session not activated"
                }
            }
        }
    }
}

if($null -eq $sessionHostPool)
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [INFO] Ending automation"
    logState -state "INFO" -logMessage "Ending automation"
    exit 0
}
else
{
    Write-Host (Get-Date -Format 'MM/dd/yyyy HH:mm:ss').ToString() " = [WARNING] Starting the countdown for user finish their job"
    $null = Start-Sleep -Seconds 60
}