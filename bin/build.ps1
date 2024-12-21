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

$Metadata = Get-Content -Raw $MetadataPath | ConvertFrom-Json -AsHashtable

$DispositionOverrides = @{
  "$($Project -replace '/','_')_Updater.exe" = "CreateIfAbsent";
};

function New-Channel {
  $ret = @{
    instance = @{};
    shared = @{
      productName = $Metadata.productName;
      windowTitle = "$($Metadata.productName) Update";
    };
    releases = @();
  };
  if ($Metadata.shared) {
    $ret.shared += $Metadata.shared;
  }
  if ($Metadata.instance) {
    $ret.instance += $Metadata.instance;
  }
  return $ret;
}


function Get-Update-Asset {
  param(
    $Release
  )

  foreach($asset in $Release.assets) {
    if ($asset.state -ne "uploaded") {
      continue;
    }
    $lower = $asset.name.ToLower();
    if ($lower -like '*debug*') {
      continue;
    }
    if ($lower -like '*symbols*') {
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

$DummyRelease = @{
  name = "Placeholder release";
  version = '0.0.0+aaaDONOTINSTALL.0';
  summary = "This release does not exist; it is included in this metadata to prevent 'no releases found' errors.";
};

function Save-Channels {
  param(
    $Prefix,
    $live,
    $test
  )

  if (!$live.releases) {
    $live.releases += $DummyRelease;
  }
  if (!$Test.releases) {
    $test.releases += $DummyRelease;
  }

  $LiveJson = "${DataRoot}/${Prefix}live.json"
  $TestJson = "${DataRoot}/${Prefix}test.json"

  $Parent = Split-Path -parent $LiveJson
  if (-not (Test-Path $Parent)) {
    New-Item -ItemType Directory $Parent
  }


  ConvertTo-json -depth 10 $live | Set-Content -Encoding UTF8 $LiveJson
  ConvertTo-json -depth 10 $test | Set-Content -Encoding UTF8 $TestJson
}

if ($Metadata.emergency) {
  $data = New-Channel
  $data.shared = @{
    detectionMethod = "FixedVersion";
    detection = @{
      version = "0.0.0";
    };
  };
  $data.instance = @{
    emergencyUrl =  $Metadata.emergency.url;
  };
  foreach($prefix in $Metadata.emergency.channelPrefixes) {
    Save-Channels $prefix $data $data
  }
}

$liveChannel = New-Channel
$testChannel = New-Channel

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
    zipExtractFileDispositionOverrides = $dispositionOverrides;
  };

  # ALL updates go to test channel
  $testChannel.releases += $release;

  # Only stable releases go to the live channel
  if (-not $gh.prerelease) {
    $liveChannel.releases += $release;
  }
}

Save-Channels $Metadata.channelPrefix $liveChannel $testChannel
