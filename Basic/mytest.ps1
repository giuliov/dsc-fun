configuration MyTestConfiguration
{
    param(
        [string] $SomeData
    )

    Import-DscResource -ModuleName PSDscResources
    
    node "localhost"
    {
        File AFolder
        {
            Ensure = "Present"
            DestinationPath = "C:\MyTest"
            Type = "Directory"
        }
        File AFile
        {
            Ensure = "Present"
            DependsOn = "[File]AFolder"
            DestinationPath = "C:\MyTest\myFile.txt"
            Type = "File"
            Contents = $SomeData
            Checksum = 'SHA-1'
            Force = $true
        }
    }#node
}

MyTestConfiguration -MachineName "localhost" -SomeData "Hello, World!"

Start-DscConfiguration ".\MyTestConfiguration" -Wait -Verbose -Force
