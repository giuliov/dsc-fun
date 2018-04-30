configuration Base1
{
    param(
        [Parameter(Mandatory)]
        $Node,
        [string]      $Ensure = "Present",
        [Parameter(Mandatory)]
        [string]      $FolderName,
        [Parameter(Mandatory)]
        [PSCredential]  $SomeCredential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    node $Node.NodeName
    {
        File AFolder
        {
            Ensure = $Ensure
            DestinationPath = $FolderName
            Type = "Directory"
        }
        File AFile
        {
            Ensure = $Ensure
            DependsOn = "[File]AFolder"
            DestinationPath = "${FolderName}\myFile.txt"
            Type = "File"
            Contents = "Some text for $( $SomeCredential.Username )"
            Checksum = 'SHA-1'
            Force = $true
        }
    }#node
}


configuration MyTestConfiguration
{
    param(
        # use either of these: PSCredential is nice for local testing, Azure Credentials for real stuff in Azure
        [string]    $SomeGlobAzureCredentialName,
        [PSCredential]  $SomeGlobCredential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    
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
