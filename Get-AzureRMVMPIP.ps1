[CmdLetBinding(DefaultParameterSetName='Name')]

param
(
    [Parameter(Mandatory=$true,ParameterSetName='Name')]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$true,ParameterSetName='Name')]
    [string] $VMName,
    [Parameter(Mandatory=$true,ParameterSetName='Object')]
    [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VMObject,
    [Parameter(Mandatory=$false,ParameterSetName='Name')]
    [Parameter(Mandatory=$false,ParameterSetName='Object')]
    [switch] $StartIfVMIsNotRunning,
    [Parameter(Mandatory=$true,ParameterSetName='Help')]
    [switch] $H
)

if ($PSCmdlet.ParameterSetName -eq 'Help' -and $H)
{
    Get-Help $PSCommandPath
    break
}

[System.Version] $RequiredModuleVersion = '6.13.1'
[System.Version] $ModuleVersion = (Get-Module -Name AzureRM).Version
if ($ModuleVersion -lt $RequiredModuleVersion)
{
    Write-Verbose -Message "Import latest AzureRM module"
    break
}

if([string]::IsNullOrEmpty($(Get-AzureRmContext)))
{ $null = Add-AzureRmAccount }

do 
{
    try
    {
        if ($PSCmdlet.ParameterSetName -eq 'Name')
        { [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status}
        elseif ($PSCmdlet.ParameterSetName -eq 'Object') { [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VM = Get-AzureRmVM -ResourceGroupName $VMObject.ResourceGroupName -Name $VMObject.Name -Status }
    }
    catch
    {
        Write-Verbose -Message $_.Exception.Message
        break
    }

    [Microsoft.Azure.Management.Compute.Models.InstanceViewStatus] $VMStatus = $VM.Statuses | Where-Object { $_.Code -match 'running' }

    if ([string]::IsNullOrEmpty($VMStatus))
    {
        Write-Verbose -Message "Since {0} VM is not running, cannot determine the public IP unless 'Public IP Allocation Method' is static" -f $VMName
        [bool] $ISVMRunning = $false
    }
    else { [bool] $ISVMRunning = $true }

    if ($ISVMRunning -eq $false -and $StartIfVMIsNotRunning -eq $true)
    {
        Start-AzureRMVM -ResourceGroupName 
    }
} while ($true) 

[string] $NICId = $VM.NetworkProfile.NetworkInterfaces.id
[Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource] $NICResource = Get-AzureRmResource -ResourceId $NICId
[string] $PIPId = $NICResource.Properties.ipConfigurations.properties.publicIPAddress.id
[Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource] $PIPResource = Get-AzureRmResource -ResourceId $PIPId
[ipaddress] $PIP = $PIPResource.Properties.ipAddress

[string] $PublicIPAllocationMethod = $PIPResource.Properties.publicIPAllocationMethod

if ([string]::IsNullOrEmpty($PIP.IPAddressToString) -and $ISVmRunning -eq $false -and $PublicIPAllocationMethod -eq 'Dynamic')
{
    Write-Verbose -Message "Since {0} VM is not running, unable to determine the Public IP"
}
return, $PIP.IPAddressToString
