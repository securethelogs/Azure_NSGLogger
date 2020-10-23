$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$rsg = "Your Resourcegroup"
$sa = "Your storage account"
$table = "Name of your table"

$key = (Get-AzStorageAccountKey -StorageAccountName $sa -ResourceGroupName $rsg).Value[0]
$context = New-AzStorageContext -StorageAccountName $sa -StorageAccountKey $key

Remove-AzStorageTable -Name $table -Context $context -Force

Start-Sleep -Seconds 60

New-AzStorageTable -Name $table -Context $context


while ((Get-AzStorageTable -Name $table -Context $context -ErrorAction SilentlyContinue) -eq $null){

Start-Sleep -Seconds 5

New-AzStorageTable -Name $table -Context $context

}




