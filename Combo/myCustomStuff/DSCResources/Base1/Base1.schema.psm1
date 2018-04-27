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

    Import-DscResource -ModuleName PSDscResources

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
