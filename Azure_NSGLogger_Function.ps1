# Input bindings are passed in via param block.
param([byte[]] $InputBlob, $TriggerMetadata)

#Remember to create the directory within the instructions
$count = ([guid]::NewGuid().tostring())
$output = "D:\home\Temp\" + $count + ".JSON"

#Your AZ resources
$rsg = "[Name of the resource group]"
$sa = "[name of the storage account]"
$container = "insights-logs-networksecuritygroupflowevent"


$bname = $($TriggerMetadata.Name)

#Get the key and set the context
$key = (Get-AzStorageAccountKey -StorageAccountName $sa -ResourceGroupName $rsg).Value[0]
$context = New-AzStorageContext -StorageAccountName $sa -StorageAccountKey $key

#This is used to get the tier of the data.
$tier = Get-AzStorageBlob -context $context -Container $container -Blob $bname


# Other tiers will fail so target on hot.
if ($tier.AccessTier -eq "Hot") {

#Get the nsg log and output to file
Get-AzStorageBlobContent -context $context -Container $container -Blob $bname -Destination $output

#get the data and destroy the file
$JSON = Get-Content -Path $output | ConvertFrom-Json
Remove-Item -Path $output -Force

$Properties =  @()

#foreach parse the logs and format for our table
for ($i=0 ;$i -lt ($JSON.records.properties.flows).Count ;$i++){
$Flow = ($JSON.records.properties.flows.flows[$i].flowtuples).Split(",")


$unixTime = $flow[0]
$date = get-date "1/1/1970"
[String]$Time = $date.AddSeconds($unixTime).ToLocalTime()


$Properties += [PSCustomObject]@{
partitionkey = $Time.substring(0,10)  -replace "/", "-"
rowkey = ([guid]::NewGuid().tostring())
Rule = $JSON.records.properties.flows.rule[$i]
Time = $Time.substring(11)
Source = $Flow[1]
Destination = $Flow[2]
SourcePort = $Flow[3]
DestinationPort = $Flow[4]
Protocol = if($Flow[5] -eq "T"){"TCP"}Else{"UDP"}
Direction = if($Flow[6] -eq "I"){"Inbound"}Else{"Outbound"}
Action = if($Flow[7] -like '*A*' ){"Allowed"}Else{"Denied"}
} 


}


#Push the data into our Table
Push-OutputBinding -Name outputTable -Value $Properties

#Clear arrary
$Properties.clear()

# Uncomment this is you wish to archive once inserted into table
#$tier.ICloudBlob.SetStandardBlobTier('Archive')

} else {}

