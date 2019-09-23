#Variables
param(
$LogFolderPath,
$LogFolder,
$LogFileName,
$SecuredPassPath,
$Domain,
$username,
$StringPasswordToCreate,
$location
)

$counter = 0
$numberOfUsers = 20
$users = New-Object System.Collections.ArrayList
$LogFile = New-Item -Path $LogFolderPath -Name $LogFileName -ItemType "file" -Force
$password = cat $SecuredPassPath | convertto-securestring
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password
$resourceGroup = "VaronisResourceGroup"
$storageAccountName = "varonisstorage"
$AzCopyUri = "https://azcopyvnext.azureedge.net/release20190517/azcopy_windows_amd64_10.1.2.zip"
$AzCopyZipFile = "C:\Program Files (x86)\Microsoft SDKs\Azure\azcopyv10.zip"
$AzCopyDest ="C:\Program Files (x86)\Microsoft SDKs\Azure\"
$securityADGroup = "Varonis Assignment2 Group"
$containerName = "logcontainer"


Write-Output "$(Get-TimeStamp) Script Started..." | Out-File -FilePath $LogFile -Append


#----------------------------------------------------------------------------

# get current time func
function Get-TimeStamp {
    
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

#----------------------------------------------------------------------------

#install AzCopy
If(!(test-path $AzCopyZipFile)){ 
try{
Invoke-WebRequest -Uri $AzCopyUri -OutFile $AzCopyZipFile
$ExtractShell = New-Object -ComObject Shell.Application
$Files = $ExtractShell.Namespace($AzCopyZipFile).Items()
$ExtractShell.NameSpace($AzCopyDest).CopyHere($Files)
$AzcopyFolder = Get-ChildItem -Path $AzCopyDest -Name azcopy_w*
$Azcopypath = "$AzCopyDest$AzcopyFolder\"
Write-output "`n$(Get-TimeStamp): AzCopy Installed" | Out-File -FilePath $LogFile -Append

}
catch{
$Exception = [Exception]::new("`n$(Get-TimeStamp): faild to install AzCopy")
Write-Output $Exception`n $_.Exception.Message | Out-File -FilePath $LogFile -Append
exit
}
}
else{
Write-output "`n$(Get-TimeStamp): AzCopy Folder Already Exist" | Out-File -FilePath $LogFile -Append
}

#----------------------------------------------------------------------------

#install Az.Resources module
if (Get-Module -ListAvailable -Name Az.Resources){
Write-output "`n$(Get-TimeStamp): Az.Resources Module Already Exist" | Out-File -FilePath $LogFile -Append
}

else{
Write-output "`n$(Get-TimeStamp): Module Does Not Exist" | Out-File -FilePath $LogFile -Append

try{
Write-output "`n$(Get-TimeStamp): Az.Resources Installation Started" | Out-File -FilePath $LogFile -Append
Install-Module -Name Az.Resources -Force
Write-output "`n$(Get-TimeStamp): Az.Resources Installed"
}

catch{
Write-output "`n$(Get-TimeStamp): Module Cannot Be Installed" | Out-File -FilePath $LogFile -Append
exit
}
}

#----------------------------------------------------------------------------

#login azure
try{
 $connection= Connect-AzAccount -credential $cred
}
catch{
 $Exception = [Exception]::new("`n$(Get-TimeStamp): Faild To Connect AzAccount")
 Write-Output $Exception`n $_.Exception.Message | Out-File -FilePath $LogFile -Append
 exit   
}

If ($connection)
{
 Write-output "`n$(Get-TimeStamp): $username Logged In" | Out-File -FilePath $LogFile -Append
 $tenant = Get-AzTenant
}
Else
{
 Write-output "`n$(Get-TimeStamp): Not Logged in" | Out-File -FilePath $LogFile -Append
 exit
}

#----------------------------------------------------------------------------

#create 20 users

for ($i=0; $i -lt $numberOfUsers; $i++){

$counter++

try{

$PasswordProfile = ConvertTo-SecureString -String $StringPasswordToCreate -AsPlainText -Force

$Displayname = "Test User $counter"

$User=New-AzADUser -DisplayName $Displayname -Password $PasswordProfile -UserPrincipalName "TestUser$counter$Domain" -MailNickName "TestUser$counter"

$users.Add($User);

Write-Output "`n$(Get-TimeStamp): User $Displayname Created" | Out-File -FilePath $LogFile -Append
}
catch{
$Exception = [Exception]::new("$(Get-TimeStamp): Faild To Create $Displayname")
Write-Output $Exception`n $_.Exception.Message | Out-File -FilePath $LogFile -Append
exit
}
}

#----------------------------------------------------------------------------

#create security group and add 20 users
$CompanyGroup = New-AzADGroup -DisplayName $securityADGroup -MailNickName "NotSet"

foreach($User in $users){
try{
$name = $user.DisplayName
$compamy = $CompanyGroup.DisplayName
Add-AzADGroupMember -MemberObjectId $User.Id -TargetGroupObjectId $CompanyGroup.Id
Write-Output "`n$(Get-TimeStamp) User $name Added To $Company" | Out-File -FilePath $LogFile -Append
}
catch{
$Exception = [Exception]::new("`n$(Get-TimeStamp): Faild To Add $name To $Company Security group") 
Write-Output $Exception`n $_.Exception.Message | Out-File -FilePath $LogFile -Append
exit
}
}

#----------------------------------------------------------------------------

# create resourceGroup 
try{
$ResourceGroupRes = Get-AzResourceGroup -Name $resourceGroup
if($ResourceGroupRes)
{
Write-Output "`n$(Get-TimeStamp): Resource Group $resourceGroup Already Exist" | Out-File -FilePath $LogFile -Append
}
else
{
New-AzResourceGroup -Name $resourceGroup -Location $location
Write-Output "`n$(Get-TimeStamp): ResourceGroup $resourceGroup Created" | Out-File -FilePath $LogFile -Append
}
}
catch{
$Exception = [Exception]::new("`n$(Get-TimeStamp): Faild To Create ResourceGroup")
Write-Output $Exception`n $_.Exception.Message | Out-File -FilePath $LogFile -Append
exit
}

#----------------------------------------------------------------------------

#create storage account and container
try{
$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName -SkuName Standard_LRS -Location $location
Write-Output "`n$(Get-TimeStamp): Storage Account $storageAccountName  Created" | Out-File -FilePath $LogFile -Append
$storageContext = $storageAccount.Context
$container = New-AzStorageContainer -Name $containerName -Context $storageContext -Permission container
$sascontext = New-AzureStorageContext -ConnectionString $storageAccount.Context.ConnectionString
$containerSas = New-AzureStorageContainerSASToken -Name $containerName -Context $sascontext -Permission rwdl
$container.CloudBlobContainer 
Write-Output "`n$(Get-TimeStamp): container $containerName Created" | Out-File -FilePath $LogFile -Append
}
catch{
$Exception = [Exception]::new("`n$(Get-TimeStamp): Faild To Create Storage Account")
Write-Output $Exception`n $_.Exception.Message | Out-File -FilePath $LogFile -Append
exit
}
#----------------------------------------------------------------------------

#azcopy copy logs 
Write-Output "$(Get-TimeStamp) Script Finished" | Out-File -FilePath $LogFile -Append
try{
$containerUri = $container.CloudBlobContainer.StorageUri.PrimaryUri.AbsoluteUri
$ContainerSasUri = "$containerUri/$containerSas"
cd $Azcopypath
.\azcopy.exe copy $LogFolderPath $ContainerSasUri --recursive=true
$LogUrl = "$containerUri/$LogFolder$LogFileName"
Write-Output "Log Uploaded, Url: $LogUrl"
}
catch{
$Exception = [Exception]::new("`n$(Get-TimeStamp): Faild To Upload Log File - $LogFolderPath\$LogFile.Name")
Write-Output $Exception`n $_.Exception.Message | Out-File -FilePath $LogFile -Append
exit
}