Set-StrictMode -Version 5

if (Get-AzureRmContext)
{
    if ([string]::IsNullOrEmpty((Get-AzureRmContext).Account)) {
        Login-AzureRmAccount
    }
}


$ResourceGroupName = "devops"
$AutomationAccountName = "DSCAutomation"
$DscConfiguration = "MyTestConfiguration"

$DscConfigurationData = @{
    AllNodes = @(
        @{
            NodeName            = "*"
        },
        @{
            NodeName            = 'dsc-tests'
            ResourceGroupName   = "devops-sandbox"
            Role                = 'WebServer'
        }
    )
}



# the configuration
function  ImportConfiguration
{
    Write-Host "Configuration Import started" -NoNewline
    $configFile = Get-Item ".\${DscConfiguration}.ps1"
    $result = Import-AzureRmAutomationDscConfiguration -SourcePath $configFile.FullName -Published -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Force
    Write-Host ", done."
}


function CompileConfiguration
{
    $johnDoeUsername = "JohnDoe" # local user: no need to specify domain
    $johnDoePassword = "Password.01" | ConvertTo-SecureString -asPlainText -Force
    $johnDoeCredential = New-Object System.Management.Automation.PSCredential -ArgumentList @($johnDoeUsername,$johnDoePassword)
    
    $SomeGlobAzureCredentialName = "JohnDoeCredential"
    if (-not (Get-AzureRmAutomationCredential -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $SomeGlobAzureCredentialName)) {
        New-AzureRmAutomationCredential -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $SomeGlobAzureCredentialName -Value $johnDoeCredential
    }
    
    $DscParameters = @{
        SomeGlobAzureCredentialName = $SomeGlobAzureCredentialName
        # or
        # SomeGlobCredential = $johnDoeCredential
    }
    
    $DscCompilationJob = Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ConfigurationName $DscConfiguration -Parameters $DscParameters -ConfigurationData $DscConfigurationData
    Write-Host "Compilation started" -NoNewline
    while ($DscCompilationJob -and $DscCompilationJob.EndTime -eq $null -and $DscCompilationJob.Exception -eq $null)
    {
        $DscCompilationJob = $DscCompilationJob | Get-AzureRmAutomationDscCompilationJob
        Start-Sleep -Seconds 3
        Write-Host "." -NoNewline
    }
    Write-Host " done."
    $DscCompilationJob | Get-AzureRmAutomationDscCompilationJobOutput -Stream Any
}


function ApplyConfiguration
{
    $RealNodes = $DscConfigurationData.AllNodes | where { $_.ContainsKey('Role') }
    foreach ($Node in $RealNodes) {
        Register-AzureRmAutomationDscNode `
            -AzureVMName $Node.NodeName -AzureVMResourceGroup $Node.ResourceGroupName `
            -NodeConfigurationName "${DscConfiguration}.$($Node.NodeName)" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
            -ConfigurationMode ApplyAndMonitor -RebootNodeIfNeeded $true -ActionAfterReboot ContinueConfiguration -AllowModuleOverwrite $true `
            -Verbose

    }
}



ImportConfiguration
CompileConfiguration
ApplyConfiguration