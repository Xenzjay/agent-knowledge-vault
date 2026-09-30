[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,
    [switch]$IncludeSuggestedSubgroups,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$targetPath = [System.IO.Path]::GetFullPath($Target)
$manifestPath = Join-Path $repoRoot "manifest\vault-manifest.json"
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json

if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
    $existing = Get-ChildItem -Force -LiteralPath $targetPath | Select-Object -First 1
    if ($existing) {
        throw "Target is not empty. Use -Force only when merging into an existing empty or disposable directory: $targetPath"
    }
}

New-Item -ItemType Directory -Force -Path $targetPath | Out-Null

$directoryPaths = [System.Collections.Generic.List[string]]::new()
foreach ($systemItem in $manifest.system) {
    $directoryPaths.Add($systemItem.name)
    foreach ($child in $systemItem.children) {
        $directoryPaths.Add((Join-Path $systemItem.name $child))
    }
}

foreach ($zone in $manifest.zones) {
    $directoryPaths.Add($zone.displayName)
    foreach ($category in $zone.categories) {
        $categoryPath = Join-Path $zone.displayName $category.displayName
        $directoryPaths.Add($categoryPath)
        if ($IncludeSuggestedSubgroups) {
            foreach ($child in $category.children) {
                $directoryPaths.Add((Join-Path $categoryPath $child))
            }
        }
    }
}

foreach ($relativePath in $directoryPaths | Sort-Object -Unique) {
    New-Item -ItemType Directory -Force -Path (Join-Path $targetPath $relativePath) | Out-Null
}

$outline = [System.Collections.Generic.List[string]]::new()
$outline.Add("# 目录结构")
$outline.Add("")
$outline.Add("此页由 manifest/vault-manifest.json 生成。")
$outline.Add("")
$outline.Add("## 创建规则")
$outline.Add("")
$outline.Add("- 默认已创建：系统目录、大区和二级分类。")
$outline.Add("- 建议三级主题仅作为分类建议展示；只有使用 -IncludeSuggestedSubgroups 时才创建对应目录。")
$outline.Add("")
$outline.Add("## 系统目录")
$outline.Add("")
foreach ($systemItem in $manifest.system) {
    $outline.Add("- $($systemItem.name)")
    foreach ($child in @($systemItem.children)) {
        $outline.Add("  - $child")
    }
}
$outline.Add("")
foreach ($zone in $manifest.zones) {
    $outline.Add("## $($zone.displayName)")
    $outline.Add("")
    foreach ($category in $zone.categories) {
        $line = "- $($category.displayName)"
        if ($category.children -and $category.children.Count -gt 0) {
            $line += "（建议三级主题未默认创建）"
            $outline.Add($line)
            $outline.Add("  - 建议主题：" + ($category.children -join "、"))
            continue
        }
        $outline.Add($line)
    }
    $outline.Add("")
}
Set-Content -LiteralPath (Join-Path $targetPath "目录结构.md") -Value $outline -Encoding utf8

Copy-Item -LiteralPath (Join-Path $repoRoot "vault\AGENTS.md") -Destination (Join-Path $targetPath "AGENTS.md") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "vault\工作区导航.md") -Destination (Join-Path $targetPath "工作区导航.md") -Force
$templateSource = Join-Path $repoRoot "templates"
$templateFiles = Get-ChildItem -LiteralPath $templateSource -File
foreach ($templateFile in $templateFiles) {
    Copy-Item -LiteralPath $templateFile.FullName -Destination (Join-Path $targetPath "_模板") -Force
}

Write-Output "Knowledge workspace created: $targetPath"
Write-Output ("Directories created: {0}" -f @($directoryPaths | Sort-Object -Unique).Count)

