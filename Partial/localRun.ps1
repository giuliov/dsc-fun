
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName                    = "*"
            PSDscAllowDomainUser        = $true
        },
        @{
            NodeName = $env:COMPUTERNAME
            Role = 'WebServer'
        }
    )
}

$aUsername = "JohnDoe" # local user: no need to specify domain
$aPassword = "Password.01" | ConvertTo-SecureString -asPlainText -Force
$aCredential = New-Object System.Management.Automation.PSCredential -ArgumentList @($aUsername,$aPassword)

MyTestConfiguration -Verbose -SomeGlobCredential $aCredential -ConfigurationData $ConfigurationData

Start-DscConfiguration ".\MyTestConfiguration" -Wait -Verbose -Force
