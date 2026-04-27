param(
  [Parameter(Mandatory = $true)]
  [string]$DocxPath,

  [string]$AssetPath = "assets/data/daily_words.json",

  [string]$BatchId = ""
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $DocxPath)) {
  throw "DOCX file not found: $DocxPath"
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-DocxParagraphs([string]$Path) {
  $stream = [System.IO.File]::Open(
    $Path,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read,
    [System.IO.FileShare]::ReadWrite
  )
  $zip = [System.IO.Compression.ZipArchive]::new(
    $stream,
    [System.IO.Compression.ZipArchiveMode]::Read
  )
  try {
    $entry = $zip.GetEntry("word/document.xml")
    if ($null -eq $entry) {
      throw "word/document.xml not found in $Path"
    }

    $reader = [System.IO.StreamReader]::new($entry.Open())
    try {
      $xml = $reader.ReadToEnd()
    } finally {
      $reader.Close()
    }
  } finally {
    $zip.Dispose()
    $stream.Dispose()
  }

  [regex]::Matches($xml, '<w:p(?:\s|>)[\s\S]*?</w:p>') |
    ForEach-Object {
      $matches = [regex]::Matches(
        $_.Value,
        '<w:t(?:\s[^>]*)?>([\s\S]*?)</w:t>|<w:tab\s*/>'
      )
      $text = ''
      foreach ($match in $matches) {
        if ($match.Value -like '<w:tab*') {
          $text += "`t"
        } else {
          $text += [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        }
      }
      ($text -replace '\s+', ' ').Trim()
    } |
    Where-Object { $_ -ne '' }
}

function Get-TextFromWordXml([string]$NodeXml) {
  $matches = [regex]::Matches(
    $NodeXml,
    '<w:t(?:\s[^>]*)?>([\s\S]*?)</w:t>|<w:tab\s*/>|<w:br\s*/>'
  )

  $text = ''
  foreach ($match in $matches) {
    if ($match.Value -like '<w:tab*' -or $match.Value -like '<w:br*') {
      $text += ' '
    } else {
      $text += [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    }
  }
  return ($text -replace '\s+', ' ').Trim()
}

function Get-DocxTableRows([string]$Path) {
  $stream = [System.IO.File]::Open(
    $Path,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read,
    [System.IO.FileShare]::ReadWrite
  )
  $zip = [System.IO.Compression.ZipArchive]::new(
    $stream,
    [System.IO.Compression.ZipArchiveMode]::Read
  )
  try {
    $entry = $zip.GetEntry("word/document.xml")
    if ($null -eq $entry) {
      throw "word/document.xml not found in $Path"
    }

    $reader = [System.IO.StreamReader]::new($entry.Open())
    try {
      $xml = $reader.ReadToEnd()
    } finally {
      $reader.Close()
    }
  } finally {
    $zip.Dispose()
    $stream.Dispose()
  }

  $rows = @()
  foreach ($row in [regex]::Matches($xml, '<w:tr[\s\S]*?</w:tr>')) {
    $cells = @(
      [regex]::Matches($row.Value, '<w:tc[\s\S]*?</w:tc>') |
        ForEach-Object { Get-TextFromWordXml $_.Value }
    )
    if ($cells.Count -gt 0) {
      $rows += ,$cells
    }
  }
  return $rows
}

function Get-StableWordId([string]$English) {
  $normalized = ($English.ToLowerInvariant() -replace '[^a-z0-9]+', '_').Trim('_')
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    $normalized = 'word'
  }

  $sha1 = [System.Security.Cryptography.SHA1]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($English.Trim().ToLowerInvariant())
  $hash = [BitConverter]::ToString($sha1.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant().Substring(0, 10)
  return "dw_${normalized}_$hash"
}

function Remove-TrailingSourceMarker([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ''
  }

  $cleaned = $Text.Trim()
  # Removes source suffixes such as "(ADA).", "(WHO·CDC)", "(KACD·AAE)."
  $cleaned = $cleaned -replace '\s*\([^)]*\)(?=\.?$)', ''
  return ($cleaned -replace '\s+', ' ').Trim()
}

function Join-MeaningAndOneLine([string]$Meaning, [string]$OneLine) {
  $meaningClean = ($Meaning -replace '\s+', ' ').Trim()
  $oneLineClean = Remove-TrailingSourceMarker $OneLine

  if ([string]::IsNullOrWhiteSpace($meaningClean)) {
    return $oneLineClean
  }
  if ([string]::IsNullOrWhiteSpace($oneLineClean)) {
    return $meaningClean
  }
  if ($oneLineClean.StartsWith($meaningClean)) {
    return $oneLineClean
  }

  return "${meaningClean}: $oneLineClean"
}

function Get-DefaultCategory($OriginalNo, [string]$BatchId, [int]$Order) {
  $textNo = [string]$OriginalNo
  if ($BatchId -eq 'clinical_terms_materials_001') {
    if ($Order -le 10) { return '진료기록·상담' }
    if ($Order -le 20) { return '보존·근관' }
    if ($Order -le 30) { return '보철·임플란트' }
    if ($Order -le 40) { return '치주·외과' }
    if ($Order -le 50) { return '교정' }
    if ($Order -le 60) { return '인상·석고' }
    if ($Order -le 70) { return '시멘트·베이스' }
    if ($Order -le 80) { return '수복·보철재료' }
    if ($Order -le 90) { return '근관·외과재료' }
    if ($Order -le 100) { return '소모품·예방재료' }
  }

  if ($textNo -match '^C(\d+)$') {
    $n = [int]$matches[1]
    if ($n -le 10) { return '진료기록·상담' }
    if ($n -le 20) { return '보존·근관' }
    if ($n -le 40) { return '보철·임플란트' }
    if ($n -le 60) { return '치주·외과' }
    if ($n -le 70) { return '교정' }
    if ($n -le 80) { return '재료·수복' }
    if ($n -le 90) { return '감염관리·교합' }
    return '영상·검사'
  }

  if ($textNo -match '^T(\d+)$') {
    $n = [int]$matches[1]
    if ($n -le 40) { return '구강해부·치아형태' }
    if ($n -le 80) { return '병리·구강질환' }
    if ($n -le 120) { return '치과재료' }
    return '전신건강·응급관리'
  }

  return '기타'
}

function Read-ExistingAsset([string]$Path) {
  if (!(Test-Path $Path)) {
    return [ordered]@{
      schemaVersion = 1
      generatedAt = (Get-Date).ToUniversalTime().ToString('o')
      nextOrder = 1
      words = @()
    }
  }

  $raw = Get-Content -Raw -Encoding UTF8 $Path
  return $raw | ConvertFrom-Json
}

$paragraphs = Get-DocxParagraphs $DocxPath
$tableRows = Get-DocxTableRows $DocxPath
$rows = @()

# New standardized format:
# ID / 용어 (EN) / 한글명 / 의미 및 쓰임 / 한줄 설명 / 출처
foreach ($cells in $tableRows) {
  if ($cells.Count -ge 6 -and $cells[0] -ne 'ID') {
    $english = $cells[1]
    $pronunciationKo = $cells[2]
    $meaning = Join-MeaningAndOneLine $cells[3] $cells[4]

    if (![string]::IsNullOrWhiteSpace($english) -and
        $english -notmatch '^(No\.|용어|한국어|의미|ID)$') {
      $rows += [pscustomobject]@{
        originalNo = $cells[0]
        english = $english
        pronunciationKo = $pronunciationKo
        meaning = $meaning
      }
    }
  }
}

# Legacy format:
# No. / English / Korean pronunciation / meaning
if ($rows.Count -eq 0) {
  for ($i = 0; $i -lt $paragraphs.Count - 3; $i++) {
    if ($paragraphs[$i] -match '^\d{1,3}$') {
      $originalNo = [int]$paragraphs[$i]
      $english = $paragraphs[$i + 1]
      $pronunciationKo = $paragraphs[$i + 2]
      $meaning = ($paragraphs[$i + 3] -replace '\s+\d+$', '').Trim()

      if ($english -notmatch '^(No\.|용어|한국어|의미)') {
        $rows += [pscustomobject]@{
          originalNo = $originalNo
          english = $english
          pronunciationKo = $pronunciationKo
          meaning = $meaning
        }
      }
    }
  }
}

if ($rows.Count -eq 0) {
  throw "No word rows were parsed. Expected legacy rows or standardized table rows."
}

$asset = Read-ExistingAsset $AssetPath
$existingWords = @($asset.words)
$existingIds = @{}
$maxOrder = 0

foreach ($word in $existingWords) {
  $existingIds[$word.id] = $true
  if ([int]$word.order -gt $maxOrder) {
    $maxOrder = [int]$word.order
  }
}

if ([string]::IsNullOrWhiteSpace($BatchId)) {
  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($DocxPath)
  $safeBase = ($baseName.ToLowerInvariant() -replace '[^a-z0-9가-힣]+', '_').Trim('_')
  $BatchId = "${safeBase}_$(Get-Date -Format 'yyyyMMddHHmmss')"
}

$added = @()
$order = $maxOrder + 1
$sourceFileName = [System.IO.Path]::GetFileName($DocxPath)

foreach ($row in $rows) {
  $id = Get-StableWordId $row.english
  if ($existingIds.ContainsKey($id)) {
    continue
  }

  $added += [ordered]@{
    id = $id
    order = $order
    english = $row.english
    pronunciationKo = $row.pronunciationKo
    meaning = $row.meaning
    category = Get-DefaultCategory $row.originalNo $BatchId $order
    sourceFileName = $sourceFileName
    sourceBatchId = $BatchId
    originalNo = $row.originalNo
    isActive = $true
  }
  $existingIds[$id] = $true
  $order++
}

$allWords = @($existingWords) + @($added)

if (@($added).Count -eq 0) {
  Write-Host "Parsed rows: $(@($rows).Count)"
  Write-Host "Added words: 0"
  Write-Host "Total words: $(@($existingWords).Count)"
  Write-Host "Next order: $($maxOrder + 1)"
  Write-Host "No new words were added; asset file was left unchanged."
  exit 0
}

$output = [ordered]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  nextOrder = $order
  words = $allWords
}

$json = $output | ConvertTo-Json -Depth 8
$dir = Split-Path -Parent $AssetPath
if ($dir -and !(Test-Path $dir)) {
  New-Item -ItemType Directory -Force $dir | Out-Null
}
[System.IO.File]::WriteAllText((Resolve-Path $dir).Path + "\" + (Split-Path -Leaf $AssetPath), $json, [System.Text.UTF8Encoding]::new($false))

Write-Host "Parsed rows: $(@($rows).Count)"
Write-Host "Added words: $(@($added).Count)"
Write-Host "Total words: $(@($allWords).Count)"
Write-Host "Next order: $order"
