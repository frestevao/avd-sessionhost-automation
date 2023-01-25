# __AZURE VIRTUAL DESKTOP - ENVIRONMENT MAINANTENCE__


This is a fork of the original source code of the AVD automation and it will be maintained by the author and community contributors.

Contents:
---
- [Solution Diagram](#solution)
- [Components Description](#description-of-the-components)
    - [Azure DevOps](#azure-devops)
        - [Pipeline](#pipelines)
        - [Service Connect](#service-connect)
        - [Self Hosted Agent](#self-host-agent)
        - [Code Repository](#code-repository)
    - [Azure](#azure)
        - [AVD Host Pool](#avd-hostpool)
        - [AVD Session Host](#avd-session-hosts)
        - [Azure Compute Gallery](#azure-compute-gallery)
        - [Azure Key Vault](#azure-keyvaults)
        - [Storage Account](#storage-account)
    - [Active Directory Domain Services (ADDS)](#active-directory-domain-services)
        - [Organizational Unity](#organizational-unity)
        - [Domain Join Account](#domain-join-account)
    - [Powershell Automations](#powershell-automations)
        - [User Notification](#usernotificationps1)
        - [Delete AVD Session Hosts](#deletesessionhostps1)
        - [Generate AVD Registration Token](#generateavdtokenidps1)
        - [Delete ADDS Computer Acount Object](#deleteadcomputeraccountps1)
        - [Deploy AVD Session Host](#newazsessionhostdeployps1)
        - [ADD VM to LAWS ](#addvmtolawsworkspaceps1)
- [Changelog](CHANGELOG.md)
- [Contributing](#Contributing)


# __<a name="solution">Solution</a>__

This solution was developed to help Azure Administrators to automate the mainatence process of AVD Environments where is required to recreate the session hosts due a image change or even for a quick deployment in another region or azure.

This automation may help you with:

- Creates a deployment pattern to your session hosts.
- Keep the AVD Organization Unity Clean.
- Grant Resources Tagging.
 
The diagram below helps you to have a better understandment of how the automation works and which componentes are used on Azure and Azure DevOps.

<img src="solutionDiagram.png" alt="project Diagram">

# __<a name="descriptionOfTheComponents">Description of the Components</a>__

## __<a name="azureDevOps">Azure DevOps</a>__
---
### __<a name="pipeline">Pipelines</a>__
---
The automation steps are executed via Azure DevOps Pipelines, this pipeline can be configured to be executed acording to your business requirement, below you may find some examples.

You can combine scheduled and event-based triggers in your pipelines, for example to validate the build every time a push is made (CI trigger), when a pull request is made (PR trigger), and a nightly build (Scheduled trigger). If you want to build your pipeline only on a schedule, and not in response to event-based triggers, ensure that your pipeline doesn't have any other triggers enabled. For example, YAML pipelines in a GitHub repository have CI triggers and PR triggers enabled by default. For information on disabling default triggers, see Triggers in Azure Pipelines and navigate to the section that covers your repository type.

1. Manual.

After create the pipeline, you'll need to trigger it manually from the Azure DevOps Portal.

```yml
    name: "Deploying Azure Virtual Desktop Session Host"
    trigger: none
    jobs: 
    - job: Deployment
      displayName: devOpsTask - Auto Task

```

2. Schedulled Trigger.

You can use cron tab to schedule the automation execution.

Scheduled triggers configure a pipeline to run on a schedule defined using [cron syntax.](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/scheduled-triggers?view=azure-devops&tabs=yaml#cron-syntax)


```yml
schedules:
- cron: string # cron syntax defining a schedule
  displayName: string # friendly name given to a specific schedule
  branches:
    include: [ string ] # which branches the schedule applies to
    exclude: [ string ] # which branches to exclude from the schedule
  always: boolean # whether to always run the pipeline or only if there have been source code changes since the last successful scheduled run. The default is false.
```
3. Branch Trigger

When specifying a branch, tag, or path, you may use an exact name or a wildcard. Wildcards patterns allow * to match zero or more characters and ? to match a single character.

- If you start your pattern with * in a YAML pipeline, you must wrap the pattern in quotes, like "*-releases".
- For branches and tags:
    - A wildcard may appear anywhere in the pattern.
- For paths:
    - In Azure DevOps Server 2022 and higher, including Azure DevOps Services, a wildcard may appear anywhere within a path pattern and you may use * or ?.
    - In Azure DevOps Server 2020 and lower, you may include * as the final character, but it doesn't do anything differently from specifying the directory name by itself. You may not include * in the middle of a path filter, and you may not use ?.

```yml
trigger:
  branches:
    include:
    - master
    - releases/*
    - feature/*
    exclude:
    - releases/old*
    - feature/*-working
  paths:
    include:
    - docs/*.md
```

To get more details about pipeline execution, please refer to the content below:

https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops&tabs=yaml#pr-triggers

https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml#pr-triggers

https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops&tabs=yaml#pr-triggers

https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/azure-repos-git?view=azure-devops&tabs=yaml#choose-a-repository-to-build


### __<a name="serviceConnect">Service Connect</a>__
---

This automation requires the usage of a service connection to execute the pipeline and succefully perform the required tasks on Azure. 

Your Microsoft Azure subscription: Create a service connection with your Microsoft Azure subscription and use the name of the service connection in an Azure Web Site Deployment task in a release pipeline.

To create a service connection you can refer to this [article](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#create-a-service-connection).


### __<a name="selfHostedAgent">Self-Host Agent</a>__
---

The pipeline needs to be executed from a self-host agent that communicates with the domain controllers of the domain where the session hosts are joined.

Requirements:

- [Powershell core](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3)
- [Az Module](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-9.3.0)
- [Az.DesktopVirtualization Module](https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/?view=azps-9.3.0)
- [Active Directory Module](https://learn.microsoft.com/en-us/powershell/module/activedirectory/?view=windowsserver2022-ps)


## __<a name="azure">Azure</a>__

### __<a name="avdHostPool">AVD HostPool</a>__
---

The automation requires an existant host pool in the Azure Subscription, you can also use the automation to update the hostpool RDP settings.

For more information about host pools, please take a look in the documentation below:

https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace?tabs=azure-portal


### __<a name="azureComputeGallery">Azure Compute Gallery</a>__
---

The automation uses the azure compute gallery image as reference for the session host deployment.

For more information about Azure Compute Gallery, please take a look in the documentation below:

https://learn.microsoft.com/en-us/azure/virtual-machines/azure-compute-gallery

### __<a name="azureKeyVault">Azure KeyVaults</a>__
---

The KeyVault is used to store:

- Domain User Join Password.
- Local Admin Password.
- AVD Registration Token.

For more information about Azure Key Vault, please take a look in the documentation below:

https://learn.microsoft.com/en-us/azure/key-vault/general/overview

### __<a name="azureIdentity">Azure Identity Assignments</a>__
---

It's required to grant access to the Service Connection in the subscription and the Key Vault.

Key Vault Permission:

https://learn.microsoft.com/en-us/azure/key-vault/general/assign-access-policy?tabs=azure-portal

> Note: For subscription, the service connection needs at least the contributor permission at the subscription level.

## __<a name="activeDirectoryDomainServices">Active Directory Domain Services</a>__

> Note: This automation only applies to scenarios where the computer are joined to an Active Directory Domain Services..

### __<a name="organizationalUnity">Organizational Unity</a>__
---

Is required to use a specific organizational unity for this automation as the script [deleteAdComputerAccount.ps1](#deleteadcomputeraccountps1) deletes all objects in the specified organizational unity.


### __<a name="domainJoinAccount">Domain Join Account</a>__
---

## __<a name="powershellAutomations">Powershell Automations</a>__

### __<a name="userNotification">userNotification.ps1</a>__
---

The userNotification.ps1 is responsible to check the session hosts avalable in the environment and notify the active users that a mainantance will happen in a few minutes and that they should save their job and finish de session.

```pwsh
#Example

./avdUserNotification.ps1   -avdHostPoolName <hostPoolName> `
                            -avdResourceGroupName <avdResourceGroupName> `
                            -avdSubscriptionName <avdSubscriptionName or SubscriptionId>

```

### __<a name="deleteSessionHost">deleteSessionHost.ps1</a>__
---
### __<a name="generateAvdTokenId">generateAvdTokenId.ps1</a>__
---
### __<a name="deleteAdComputerAccount">deleteAdComputerAccount.ps1</a>__
---
### __<a name="newAzSessionHostDeploy">newAzSessionHostDeploy.ps1</a>__
---
### __<a name="addVmToLawsWorkspace">addVmToLawsWorkspace.ps1</a>__
---

# __<a name="contributing">Contributing</a>__

This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.microsoft.com.