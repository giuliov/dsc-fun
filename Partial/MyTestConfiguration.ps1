configuration MyTestConfiguration
{
    param(
        # use either of these: PSCredential is nice for local testing, Azure Credentials for real stuff in Azure
        [string]    $SomeGlobAzureCredentialName,
        [PSCredential]  $SomeGlobCredential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName myCustomStuff
    
    if ($SomeGlobCredential -eq $null) {
        $SomeGlobCredential = Get-AutomationPSCredential $SomeGlobAzureCredentialName
    }

    node $AllNodes.Where{$_.Role -eq "WebServer"}.NodeName
    {
        Base1 instanceOne
        {
            Ensure = "Present"
            Node = $Node # forward configuration data
            FolderName = "C:\MyTest1"
            SomeCredential = $SomeGlobCredential
        }
    }#node
}
