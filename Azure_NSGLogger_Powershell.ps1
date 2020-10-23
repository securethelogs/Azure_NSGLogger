

$logo = @('


  █████╗ ███████╗██╗   ██╗██████╗ ███████╗    ███╗   ██╗███████╗ ██████╗ ██╗      ██████╗  ██████╗  ██████╗ ███████╗██████╗ 
 ██╔══██╗╚══███╔╝██║   ██║██╔══██╗██╔════╝    ████╗  ██║██╔════╝██╔════╝ ██║     ██╔═══██╗██╔════╝ ██╔════╝ ██╔════╝██╔══██╗
 ███████║  ███╔╝ ██║   ██║██████╔╝█████╗      ██╔██╗ ██║███████╗██║  ███╗██║     ██║   ██║██║  ███╗██║  ███╗█████╗  ██████╔╝
 ██╔══██║ ███╔╝  ██║   ██║██╔══██╗██╔══╝      ██║╚██╗██║╚════██║██║   ██║██║     ██║   ██║██║   ██║██║   ██║██╔══╝  ██╔══██╗
 ██║  ██║███████╗╚██████╔╝██║  ██║███████╗    ██║ ╚████║███████║╚██████╔╝███████╗╚██████╔╝╚██████╔╝╚██████╔╝███████╗██║  ██║
 ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝
                                                                                                                           
                                                                             
 Creator: Securethelogs.com / @securethelogs
')



$logo

Write-Host " Note: This will create the following directory: C:\Azure\NSGlogger\" -ForegroundColor Red

$container = "insights-logs-networksecuritygroupflowevent"
$count = 0


$output = "C:\Azure\NSGlogger\"

New-Item $output -ItemType Directory -Force | Out-Null

Remove-Item ($output + "\*") -Recurse -Force -ErrorAction SilentlyContinue

Write-Output ""

$sub = Read-Host -Prompt " Subscription Name"

try { Set-AzContext -SubscriptionName $sub  | Out-Null} catch { Write-Host "Error, closing script...."; end } 


Write-Host " [*] Connected to Azure..." -ForegroundColor Green

Write-Output ""

$sa = Read-Host -Prompt " Storage Account Name"
$rsg = Read-Host -Prompt " Resource Group Name"

    
$key = (Get-AzStorageAccountKey -StorageAccountName $sa -ResourceGroupName $rsg).Value[0]

$blobs = @((New-AzStorageContext -StorageAccountName $sa -StorageAccountKey $key | Get-AzStorageBlob -Container $container).Name) 

Remove-Item ($output + "\*") -Recurse -Force

Write-Host " Downloading NSG Logs ........" -ForegroundColor Green

Write-Output ""

$time = "d=" + (Get-Date -Format dd)
$hr = (Get-Date).Hour
$hrm = $hr - 1

if (($hr).count -eq 1){$hr = "0" + $hr}
if (($hrm).count -eq 1){$hrm = "0" + $hrm}


$hr = "h=" + $hr
$hrm = "h=" + $hrm



    foreach ($b in $blobs){
    
        # Filters on 1 hour back

        if ($b.Contains($time) -and $b.Contains($hr) -or $b.Contains($time) -and $b.Contains($hrm) ){
            
            $b
            $count++
            New-AzStorageContext -StorageAccountName $sa -StorageAccountKey $key | Get-AzStorageBlobContent -Container $container -Blob $b -Destination ($output + "NSG-$count.JSON")
        
        
        }
        
       
    
    
    }




$nsgf = @((Get-ChildItem $output).FullName)
$log = @()

foreach ($nf in $nsgf){



$a = (Get-Content -Path $nf | Out-String)



$b = @($a -split ('}') -replace "]", "" -replace " ","")
$m = @()

foreach ($c in $b){

 if ($c.StartsWith(',{"time')){
  
 $m += $c -replace ',"' , "`n" -replace ',{"' , ""
 
 }

}


foreach ($t in $m){


$i = @($t -split "`n")



    foreach ($v in $i){


    if ($v.StartsWith("time")){
    
    
    $time = $v -replace '"', "" -replace "time:", ""
    $time = @($time.Split("T"))
    $time = $time[1]
    $time = $time.Substring(0,8)
    
    
    }
    if ($v.StartsWith("flows") -and $v.contains('rule":')){$name = @($v -split ":")}
        

        if ($v.contains(",I,") -or $v.contains(",O,")){

            
        
            $r = @($v -split ",")

            $rulename = $name[2] -replace '"', ""
            $source = $r[1]
            $destination = $r[2]
            $sourceprt = $r[3]
            $destport = $r[4]
            
                      
            if ($r[5] -eq "T"){$protocol = "TCP" }else{$protocol = "UDP"}
            if ($r[6] -eq "I"){$direction = "Inbound"  }else{$direction = "Outbound"  }
            if ($r[7] -like '*A*'){$action = "Allowed"}else{$action = "Denied"}


            
            $log += @{Time=$time;Source=$source;Destination=$destination;SourcePort=$sourceprt;DestinationPort=$destport;Protocol=$protocol;Direction=$direction;Action=$action;Rule=$rulename} | % { New-Object object | Add-Member -NotePropertyMembers $_ -PassThru }

        
    
    
    }



 }



} 

Write-Host " Processing $nf...."

} 

Write-Output ""


Write-Host " Loading Logs ......"


$log | Select-Object Time, Source, Destination, SourcePort, DestinationPort, Protocol, Direction, Action, Rule | Out-GridView -Title "Azure NSG"


Remove-Item ($output + "\*.JSON") -Recurse -Force

Write-Output ""

Write-Host " Deleteing Temp Files ........" -ForegroundColor Red


