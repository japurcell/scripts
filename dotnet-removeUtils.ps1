# Last Updated: 8/22/2018 - JPurcell

<#
.SYNOPSIS
Gets installed .NET Core packages on local machine.

.INPUTS
None.

.OUTPUTS
System.Management.ManagementObject. Get-CoreProducts returns an object for
each .NET Core installation.

.EXAMPLE

PS C:\> Get-CoreProducts | ft Name, Version, Ident*
Name                         Version    IdentifyingNumber
----                         -------    -----------------
NET Core SDK - 2.1.400 (x64) 8.116.9197 {FA2E3CCB-4297-42D1-ABC2-01AE6F6098A7}

#>
function Get-CoreProducts
{
    $filter = "Name LIKE '%NET Core%'"
    $filter | Write-Verbose

    Get-WmiObject -Class Win32_Product -Filter $filter `
    | Sort-Object Version
}

<#
.SYNOPSIS
Filters Management Objects by version matching.

.PARAMETER objects
The ManagementObjects to filter.

.PARAMETER versions
Specifies the versions to match on.

.INPUTS
System.Management.ManagementObject. The objects to be filtered.

.OUTPUTS
System.Management.ManagementObject. Select-Versions returns the objects
that match any of the versions.

.EXAMPLE

PS C:\> Get-CoreProducts | Select-Versions '1.2*', '3.4.1'
Name                         Version    IdentifyingNumber
----                         -------    -----------------
NET Core SDK - 2.1.1 (x64)   1.2.9197   {FA2E3CCB-4297-42D1-ABC2-01AE6F6098A7}
NET Core SDK - 2.1.4 (x64)   3.4.1      {FA2E3CTY-4267-42D2-ABC2-01AE6F6000ER}

#>
function Select-Versions
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [System.Management.ManagementObject[]]
        $objects,

        [Parameter()]
        [string[]]
        $versions
    )

    process
    {
        "Pipeline: $_" | Write-Debug

        $likes = @()

        $versions |% `
        {
            $likes += '$_.Version -like ''' + $_ + ''''
        }

        $expression = $likes -join " -or "

        $filterBlock = [scriptblock]::Create($expression)
        $filterBlock | Write-Debug

        $objects | where -FilterScript $filterBlock
    }
}

<#
.SYNOPSIS
Uses msiexec.exe to uninstall .NET Core products.

.DESCRIPTION

Msiexec must be run with a GUI for .NET Core products;
otherwise, they aren't fully unregistered. So this function
must be run interactively on a single machine.

.PARAMETER objects
The ManagementObjects to be removed.

.PARAMETER logFile
Specifies the log file location for msiexec to write to.

.INPUTS
System.Management.ManagementObject. The objects to be removed.

.OUTPUTS
System.Diagnostics.Process. The msiexec process.

.EXAMPLE

PS C:\> Get-CoreProducts |? { $_.Version -like '2.0.1*' } | Uninstall-Objects
Uninstalling Microsoft ASP.NET Core 2.0.9 Runtime Package Store (x64)
PS C:\>

.EXAMPLE

PS C:\> Get-CoreProducts | Select-Versions -versions '2.0.1*' } | Uninstall-Objects
Uninstalling Microsoft ASP.NET Core 2.0.9 Runtime Package Store (x64)
PS C:\>

#>
function Uninstall-Objects
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [System.Management.ManagementObject[]]
        $objects,

        [Parameter()]
        [string]
        $logFile
    )
    
    begin
    {
        Add-Type -AssemblyName "System.Management"
        $accelerators = [psobject].Assembly.GetType("System.Management.Automation.TypeAccelerators")
        $accelerators::Add('System.Management.ManagementObject', [System.Management.ManagementObject])
    }

    process
    {
        $alist = '/x{0}'

        if (![string]::IsNullOrEmpty($logFile))
        {
            $alist = $alist + "/lie+! $logFile"
        }

        $alist = $alist -f $_.IdentifyingNumber
        "Calling msiexec with $alist" | Write-Verbose

        "Uninstalling $($_.Name)" | Write-Verbose

        Start-Process -Wait -PassThru 'msiexec' -ArgumentList $alist
    }
}