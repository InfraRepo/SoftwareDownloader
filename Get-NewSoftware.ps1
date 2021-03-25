<#
.SYNOPSIS
    Compare local and remote file (by date) and download new version if available.
.EXAMPLE
    PS C:\> .\Get-NewSoftware.ps1
.EXAMPLE
    PS C:\> .\Get-NewSoftware.ps1 -verbose
.INPUTS
    None.
.OUTPUTS
    None.
.LINK
#>

[CmdletBinding()]
param (
    [string]$SettingsFileName = 'AppSettings.xml',
	[string]$LogsDir = 'Logs',
	[string]$PackageFilter = ''
)

$SettingsFilePath = Join-Path $PSScriptRoot $SettingsFileName
Write-Verbose $SettingsFilePath
$LogsDirPath = Join-Path $PSScriptRoot $LogsDir
Write-Verbose $LogsDirPath

If(!(test-path $LogsDirPath)){
    New-Item -ItemType Directory -Force -Path $LogsDirPath | Out-Null
}

Function LogChange($LogFile, $param1){
    $timestamp = get-date -Format 'yyyyMMddHHmmss'
    $entry = "$timestamp,$param1"
    $LogFilePath = Join-Path $LogsDirPath $LogFile
    Add-Content $LogFilePath $entry
}

Function GetRemoteFileDate($URL){
	$WebRequest = [System.Net.HttpWebRequest]::Create($URL)
	$WebRequest.Method = "HEAD"
	$WebResponse = $WebRequest.GetResponse()

	If($WebResponse.StatusCode -eq 'OK'){
		[DateTime]$ModifiedDate = $WebResponse.LastModified
		Write-Host " Modified-server:   " $ModifiedDate
		return $ModifiedDate
	}
	else{
		Write-Error "Failed to check remote file version!"
		return 1
	}
}

Function GetLocalFileDate($DownloadDir, $File){
	write-host " Filter:            " $File
	write-host " Directory:         " $DownloadDir
	$FilePath = Get-ChildItem $DownloadDir -filter $File
	Write-Host " Tested file:       " $FilePath

	If ($FilePath){
		if (Test-Path $FilePath -PathType Leaf){
			[datetime]$FileLastWrite = $FilePath.LastWriteTime
			Write-Verbose "Local file exists."
			Write-Host " Modified-local:    " $FileLastWrite
			return $FileLastWrite
		}
		else{
			Write-host " File doesn't exist!"
			return 1
		}
	}
	else{
		write-host " File doesn't exist!"
		return 1
	}
}

Function DownloadHTTPFile($URL, $DownloadDir, $Filename){
	$DestFile = "$DownloadDir\$FileName"
	try{
		Invoke-WebRequest -Uri $URL -OutFile $DestFile
		LogChange $GeneralLogFile "$FileName updated"
	}
	catch{
		LogChange $GeneralLogFile "$FileName failed to download"
	}
}

Function FindURLOnGithub($repo, $FileNamePattern){
	$ReleasesURI = "https://api.github.com/repos/$repo/releases/latest"
    $DownloadURI = ((Invoke-RestMethod -Method GET -Uri $ReleasesURI).assets | Where-Object name -like $FileNamePattern ).browser_download_url
	return $DownloadURI
}

Function FindURLOnWebsite($URL, $DownloadURL, $FileNamePattern){
	Write-Verbose "URL:         [$URL]"
	Write-Verbose "DownloadURL: [$DownloadURL]"
	Write-Verbose "Pattern:     [$FileNamePattern]"
	$Content = Invoke-WebRequest -Uri $URL
	$FileName = ($Content.Links | Where-Object {$_.href -like $FileNamePattern }).href
	If($DownloadURL){
		$FileURL = $DownloadURL + $FileName
	}
	else{
		$FileURL = $URL + $FileName
	}
	return $FileURL
}
Function GetURL($Package){
	switch ($Package.Method) {
		DirectURL { return $Package.URL }
		FindOnGithub { return FindURLOnGithub $Package.GithubRepo $Package.GithubPattern }
		FindOnWebsite { return FindURLOnWebsite $Package.URL $Package.DownloadURL $Package.FileNamePattern }
		Default {}
	}
}

If(Test-Path $SettingsFileName){
	#Load settings
	$Set = [XML](Get-Content $SettingsFilePath)
	$GeneralLogFile = $Set.App.Settings.GeneralLogFile
	Write-Verbose $GeneralLogFile

	# Start logging
	LogChange $GeneralLogFile "Start"

	If($PackageFilter){
		$Filter = "*$PackageFilter*"
		$Packages = $Set.App.Packages.Package | where-object {$_.Name -like $filter}
	}
	else{
		$Packages = $Set.App.Packages.Package
	}

	# For Each software
	Foreach ($Package in $Packages){
		write-host "==================================="
		Write-Output "Package:      [$($Package.Name)]"
		Write-Output "File:         [$($Package.FileName)]"

		### TODO Address operations here: find, extract, calculate etc
		Write-Output "URL:          [$($Package.URL)]"
		Write-Output "Enabled:      [$($Package.Enabled)]"

		If($Package.Enabled -ne 0){
			#Find remote file direct URL
			$RemoteFileURL = GetURL $package

			If($Package.DownloadDir){
				$DownloadDir = $Package.DownloadDir
				Write-Verbose "Custom download directory: [$DownloadDir]"
			}
			else{
				$DownloadDir = $Set.App.Settings.DownloadDir
			}

			# check version
			$LocalFileDate = GetLocalFileDate $DownloadDir $Package.FileName
			$RemoteFileDate = GetRemoteFileDate $RemoteFileURL

			if ($RemoteFileDate -ge $LocalFileDate){
				write-host "   --------> New version available"
				DownloadHTTPFile $RemoteFileURL $DownloadDir $Package.FileName
			}
			else{
				write-host "   --------> No new versions"
			}
		}
		else{
			Write-Output "   -------->  File not checked - disabled in config"
		}
	}
	LogChange $GeneralLogFile "Stop"
}
Else{
	Write-Error "Settings file does not exist!"
}