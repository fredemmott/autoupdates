param(
  [Parameter(Mandatory)]
  [string] $Project
)

$DataRoot = "${PSScriptRoot}/../data/${Project}"
$MetadataPath = "${PSScriptRoot}/../config/${Project}.json"

if (-not (Test-Path $MetadataPath)) {
  echo "Could not find ${MetadataPath}"
  return;
}

$Metadata = Get-Content -Raw $MetadataPath | ConvertFrom-Json

$liveChannel = @{
  shared = @{
    productName = $Metadata.productName;
    windowTitle = "$($Metadata.productName) Update";
    runAsTemporaryCopy = $true;
  };
  releases = @();
};
# Deep copy
$testChannel = ConvertTo-Json $liveChannel | ConvertFrom-Json

function Get-Update-Asset {
  param(
    $Release
  )

  foreach($asset in $Release.assets) {
    if ($asset.state -ne "uploaded") {
      continue;
    }
    $lower = $asset.name.ToLower();
    if ($lower -contains 'debug') {
      continue;
    }
    if ($lower -contains 'symbols') {
      continue;
    }
  
    return $asset;
  }


  return $null;
}

function Normalize-Version {
  param(
    $Version
  )

  # v1.2.3 => 1.2.3
  $Version = $Version -replace '^v','';
  # VERSIONINFO-style a.b.c.d => a.b.c
  $Version = $Version -replace '^(([0-9]+)\.){3}\.[0-9]+','$1'
  # 2024.03.04 => 2024.3.4
  $Version = $Version -replace '\b0([0-9]+)+','$1'
  # -rc1/-beta1 need to be -rc.1 or -beta.1
  $Version = $Version -replace '-([a-z]+)([0-9]+)','-$1.$2'
  return $Version
}

function Normalize-Body {
  param(
    $Body
  )

  # Look for 'Download from <link>' or 'please link to /releases/latest'
  $index = $Body.LastIndexOf('/releases/')

  if ($index -eq -1) {
    return $Body;
  }

  $Body = $Body.Substring($index)

  $Lines = $Body -Split "`n"
  
  $InPreamble = 0;
  $ChompingSeparators = 1;
  $InBody = 2;

  $FilteredLines = @();

  $State = $InPreamble;
  foreach($Line in $Lines) {
    $Line = $Line.TrimEnd();

    if ($State -eq $InPreamble) {
      if ($Line -ne "") {
        continue;
      }
      $State = $ChompingSeparators;
      continue;
    }
    
    if ($State -eq $ChompingSeparators) {
      if ($Line -eq "") {
        continue;
      }
      if ($Line -eq "---") {
        continue;
      }
      $State = $InBody;
    }

    $FilteredLines += $Line;
  }

  return $FilteredLines -join "`n";
}

$githubReleases = Invoke-RestMethod -uri "https://api.github.com/repos/${Project}/releases"
foreach($gh in $githubReleases) {
  $asset = Get-Update-Asset($gh);
  $release = @{
    name = $gh.name;
    version = Normalize-Version($gh.tag_name);
    summary = Normalize-Body($gh.body);
    publishedAt = $gh.published_at;
    downloadUrl = $asset.browser_download_url;
    downloadSize = $asset.size;
  };

  # ALL updates go to test channel
  $testChannel.releases += $release;

  # Only stable releases go to the live channel
  if (-not $gh.prerelease) {
    $liveChannel.releases += $release;
  }
}

if (-not (Test-Path $DataRoot)) {
  New-Item -ItemType Directory $DataRoot
}

ConvertTo-json $liveChannel | Set-Content -Encoding UTF8 "${DataRoot}/live.json"
ConvertTo-json $testChannel | Set-Content -Encoding UTF8 "${DataRoot}/test.json"
