<#
Run the following before local testing

Install-Module -Force -Name PSDscResources,xWebAdministration,xNetworking
#>

configuration TestWebConfiguration
{
    param(
        [string[]]      $MachineName = "localhost"
    )

    # assume that the second disk is the data disk
    $DataDrive = (Get-PSDrive -PSProvider FileSystem | where Free -NE $null | sort Name | select -Skip 1 -First 1).Root
    $SitesRootFolder = "${DataDrive}Sites"
    $SitesLogDirectory = "${DataDrive}IisLogs"

    Import-DscResource -ModuleName PSDscResources
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xNetworking
    
    node $MachineName
    {
        WindowsFeatureSet IIS
        {
            Ensure = "Present"
            Name = "Web-Default-Doc", "Web-Dir-Browsing", "Web-Http-Errors", "Web-Static-Content", "Web-Http-Redirect", "Web-Http-Logging", "Web-Request-Monitor", "Web-Http-Tracing", "Web-Filtering", "Web-Net-Ext45", "Web-Asp-Net45", "Web-ISAPI-Ext", "Web-ISAPI-Filter"
        }
        WindowsFeatureSet WebManagement
        {
            Ensure = "Present"
            Name = "Web-Mgmt-Console"
        }
        WindowsFeatureSet AppStack
        {
            Ensure = "Present"
            Name = "NET-Framework-45-ASPNET"
        }


        # common to all sites
        File SitesRootFolder
        {
            Ensure = "Present"
            DestinationPath = $SitesRootFolder
            Type = "Directory"
        }
        File SitesLogDirectory
        {
            Ensure = "Present"
            DestinationPath = $SitesLogDirectory
            Type = "Directory"
        }
        xFirewall HttpIn
        {
            Ensure = 'Present'
            Name = "http"
            DisplayName = "MyWeb (HTTP-In)"
            Enabled = $true
            Action = 'Allow'
            Profile = 'Any'
            Direction = 'Inbound'
            LocalPort = 80
            Protocol = 'TCP'
        }
        xFirewall HttpsIn
        {
            Ensure = 'Present'
            Name = "https"
            DisplayName = "MyWeb (HTTPS-In)"
            Enabled = $true
            Action = 'Allow'
            Profile = 'Any'
            Direction = 'Inbound'
            LocalPort = 443
            Protocol = 'TCP'
        }
        xWebSiteDefaults SitesDefaults
        {
            DependsOn = "[File]SitesLogDirectory"
            ApplyTo = 'Machine'
            LogFormat = 'IIS'
            LogDirectory = $SitesLogDirectory
            AllowSubDirConfig = 'true'
        }
        xWebsite RemoveDefaultWebSite
        {
            Ensure = "Absent"
            DependsOn = "[WindowsFeatureSet]IIS"
            Name = "Default Web Site"
        }
        xWebAppPool RemoveDefaultAppPool
        {
            Ensure = "Absent"
            DependsOn = "[xWebsite]RemoveDefaultWebSite"
            Name = "DefaultAppPool"
        }

        $AppName = 'MyWeb'
        $AppInstallFolder = "${SitesRootFolder}\${AppName}"
        File "${AppName}_ApplicationFolder"
        {
            Ensure = "Present"
            DependsOn = "[File]SitesRootFolder"
            DestinationPath = $AppInstallFolder
            Type = "Directory"
        }
        $AppLogFolder = "${SitesLogDirectory}\${AppName}"
        File "${AppName}_LogFolder"
        {
            Ensure = "Present"
            DependsOn = "[File]SitesRootFolder"
            DestinationPath = $AppLogFolder
            Type = "Directory"
        }
        xWebAppPool "${AppName}_AppPool"
        {
            Ensure = "Present"
            DependsOn = "[WindowsFeatureSet]IIS"
            Name = $AppName
            EnableConfigurationOverride = $true
            IdentityType = "ApplicationPoolIdentity"
            ManagedRuntimeVersion = 'v4.0'
            LoadUserProfile = $false
        }
        
        # BINDING FUN
        
        # SelfSigned SSL Certificate
        $FQDNs = @(
            "${env:COMPUTERNAME}.example.com",
            "${AppName}-test.example.com",
            "test.${AppName}.example.com"
        )
        $FQDNsAsString = $FQDNs -join ';'

        Script "${AppName}_Create_SelfSignedSSLCertificate"
        {
            DependsOn = "[WindowsFeatureSet]IIS"
            GetScript = {
                $cert = Get-ChildItem "cert:\LocalMachine\WebHosting" | where { $_.FriendlyName -eq $using:AppName }
                return @{ 'Result' = $cert }
            }
            SetScript = {
                $FQDNs = $using:FQDNs # AsString -split ';'
                $AppName = $using:AppName
                Write-Verbose "FQDNs = ${FQDNs}"
                # DnsName accepts an array of DNS names
                $cert = New-SelfSignedCertificate -DnsName $FQDNs -CertStoreLocation "cert:\LocalMachine\My"
                Write-Verbose "Created '${AppName}' Certificate $($cert.Thumbprint)"
                $cert.FriendlyName = $using:AppName # this is the key to pick the cert later on!
                Move-Item -Path "cert:\LocalMachine\My\$($cert.Thumbprint)" -Destination "cert:\LocalMachine\WebHosting"
            }
            TestScript = {
                $cert = Get-ChildItem "cert:\LocalMachine\WebHosting" | where { $_.FriendlyName -eq $using:AppName }
                # TODO check that $cert.DnsNameList matches!!!
                return $cert -ne $null
            }
        }
        
        $SubjectName = $FQDNs[0]
        $BindingInfo = $FQDNs | foreach {
            MSFT_xWebBindingInformation {
                Protocol  = "https"
                IPAddress = '*'
                Port      = 443
                HostName  = $_
                CertificateSubject = $SubjectName
                CertificateStoreName = 'WebHosting'
            }
        }

        xWebsite "${AppName}_WebSite"
        {
            Ensure = "Present"
            DependsOn = "[File]${AppName}_ApplicationFolder","[xWebAppPool]${AppName}_AppPool","[Script]${AppName}_Create_SelfSignedSSLCertificate"
            Name = $AppName
            PhysicalPath = $AppInstallFolder
            LogPath = $AppLogFolder
            State = 'Started'
            ApplicationPool = $AppName
            BindingInfo = $BindingInfo
        }

    }#node
}

#****************************************************
#	Lines below are used for debugging when running
#	on the VM.
#****************************************************
$ConfigurationData = @{
    AllNodes = @(    
        @{  
            NodeName = "localhost"
            PSDscAllowDomainUser        = $true
        }
    ) 
}

TestWebConfiguration -MachineName "localhost" -ConfigurationData $ConfigurationData

Start-DscConfiguration ".\TestWebConfiguration" -Wait -Verbose -Force
