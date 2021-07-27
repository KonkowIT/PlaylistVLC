$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$FolderOfVideos = "Z:\OutDoor" 
#$FolderOfVideos = "Z:\InDoor" 
#$FolderOfVideos = "W:\AktualnaPlaylista\InDoor"

$start = @"
<?xml version="1.0" encoding="UTF-8"?>
<playlist xmlns="http://xspf.org/ns/0/" xmlns:vlc="http://www.videolan.org/vlc/playlist/ns/0/" version="1">
	<title>Spoty</title>
	<trackList>
"@

$middle = @"
	</trackList>
	<extension application="http://www.videolan.org/vlc/playlist/0">
"@

$end = @"
	</extension>
</playlist>
"@

$z = Get-SmbMapping | where { $_.localPath -eq "Z:" }
$global:counter = 0
$date = get-date -Format "dd-MM-yyyy"

function AddTrack {
  param (
    [string]$file,
    [Int]$dur,
    [Int]$count
  )

  $file = @"
		<track>
			<location>file:///$($file)</location>
			<duration>$($dur)</duration>
			<extension application="http://www.videolan.org/vlc/playlist/0">
				<vlc:id>$($count)</vlc:id>
			</extension>
		</track>
"@

  $global:counter ++

  return $file
}

Function Get-FileMetaData {
  Param([string[]]$folder)
  foreach ($sFolder in $folder) {
    $a = 0
    $objShell = New-Object -ComObject Shell.Application
    $objFolder = $objShell.namespace($sFolder)

    foreach ($File in $objFolder.items()) { 
      $FileMetaData = New-Object PSOBJECT
      for ($a ; $a -le 266; $a++) { 
        if ($objFolder.getDetailsOf($File, $a)) {
          $hash += @{ $($objFolder.getDetailsOf($objFolder.items, $a)) = $($objFolder.getDetailsOf($File, $a)) }
          $FileMetaData | Add-Member $hash
          $hash.clear() 
        } 
      }
      $a = 0
      $FileMetaData
    } 
  }
}

# === START

if ($z.Status -eq "Unavailable") {
  try {
    New-SmbMapping -LocalPath $z.LocalPath -RemotePath $z.RemotePath -Persistent $True | out-null
  }
  catch {
    Write-Host "Connection error: $($z.RemotePath) to drive $($z.LocalPath)"
  }
} 

gci $FolderOfVideos -Recurse | % {
  if ((!($_.name.EndsWith("odw.mp4"))) -and $_.name.EndsWith(".mp4")) {
    $d = $_.Name.split("_do-")[-1]
    $d = ( -join ($d.TrimEnd(".mp4").Insert(2, "-"), "-2020"))
    $d = [datetime]::ParseExact($d, "dd-MM-yyyy", $null)

    if ((New-TimeSpan -Start $date -End $d).Days -lt 0) {
      "Removing: $($_.name)"
      Remove-item $_.FullName -Force
    }
  }
}

New-Item -Path "$($env:USERPROFILE)\Desktop" -Name "vlc_playlist.xspf" -ItemType File -Force 
ac "$($env:USERPROFILE)\Desktop\vlc_playlist.xspf" -Value $start

$listOfVideos = Get-FileMetaData -folder $FolderOfVideos | select Ścieżka, Długość

foreach ($video in $listOfVideos) {
  $mp4 = ($video.Ścieżka).Replace('\', '/')
  try {
    $time = (([TimeSpan]::Parse($video.Długość)).TotalSeconds) * 1000
  }
  catch {
    $time = 10000
  }

  ac "$($env:USERPROFILE)\Desktop\vlc_playlist.xspf" -value (AddTrack -file $mp4 -dur $time -count $global:counter)
}

ac "$($env:USERPROFILE)\Desktop\vlc_playlist.xspf" -value $middle

for ($i = 0; $i -lt $global:counter; $i ++) { 
  $id = @"
		<vlc:item tid="$($i)"/>
"@
  ac "$($env:USERPROFILE)\Desktop\vlc_playlist.xspf" -value $id
}

ac "$($env:USERPROFILE)\Desktop\vlc_playlist.xspf" -value $end