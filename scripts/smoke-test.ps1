[CmdletBinding()]
param(
    [switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$bootstrapPath = Join-Path $scriptRoot 'bootstrap.ps1'
$validatePath = Join-Path $scriptRoot 'validate.ps1'
$manifestPath = Join-Path $repoRoot 'manifest\vault-manifest.json'

$assertions = 0

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    $script:assertions++
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-PathExists {
    param([string]$Path)
    Assert-Condition -Condition (Test-Path -LiteralPath $Path) -Message "Expected path to exist: $Path"
}

function Assert-PathMissing {
    param([string]$Path)
    Assert-Condition -Condition (-not (Test-Path -LiteralPath $Path)) -Message "Expected path to be absent: $Path"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$tempRoot = Join-Path $env:TEMP ("knowledge-workspace-smoke-" + [guid]::NewGuid().ToString('N'))
$defaultTarget = Join-Path $tempRoot 'default'
$expandedTarget = Join-Path $tempRoot 'expanded'
$mergeTarget = Join-Path $tempRoot 'merge'

try {
    & $validatePath -Path $repoRoot | Out-Null

    & $bootstrapPath -Target $defaultTarget | Out-Null
    $expectedSecondLevel = @($manifest.zones | ForEach-Object { $_.categories } | Measure-Object).Count
    foreach ($zone in @($manifest.zones)) {
        Assert-PathExists -Path (Join-Path $defaultTarget $zone.displayName)
        foreach ($category in @($zone.categories)) {
            $categoryPath = Join-Path (Join-Path $defaultTarget $zone.displayName) $category.displayName
            Assert-PathExists -Path $categoryPath
            foreach ($child in @($category.children | Where-Object { $null -ne $_ })) {
                Assert-PathMissing -Path (Join-Path $categoryPath $child)
            }
        }
    }
    Assert-PathExists -Path (Join-Path $defaultTarget '目录结构.md')
    Assert-PathExists -Path (Join-Path $defaultTarget 'AGENTS.md')
    Assert-PathExists -Path (Join-Path $defaultTarget '工作区导航.md')
    Assert-PathExists -Path (Join-Path $defaultTarget '_模板')
    $outline = Get-Content -Raw -LiteralPath (Join-Path $defaultTarget '目录结构.md')
    Assert-Condition -Condition ($outline -match '建议三级主题仅作为分类建议展示') -Message 'Generated outline does not explain optional subgroups.'

    & $bootstrapPath -Target $expandedTarget -IncludeSuggestedSubgroups | Out-Null
    foreach ($zone in @($manifest.zones)) {
        foreach ($category in @($zone.categories)) {
            $categoryPath = Join-Path (Join-Path $expandedTarget $zone.displayName) $category.displayName
            foreach ($child in @($category.children | Where-Object { $null -ne $_ })) {
                Assert-PathExists -Path (Join-Path $categoryPath $child)
            }
        }
    }

    New-Item -ItemType Directory -Force -Path $mergeTarget | Out-Null
    $keepFile = Join-Path $mergeTarget 'keep-me.txt'
    $outlinePath = Join-Path $mergeTarget '目录结构.md'
    $templatePath = Join-Path (Join-Path $mergeTarget '_模板') '资源索引模板.md'
    Set-Content -LiteralPath $keepFile -Value 'preserve' -Encoding utf8
    Set-Content -LiteralPath $outlinePath -Value 'stale generated content' -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $templatePath) | Out-Null
    Set-Content -LiteralPath $templatePath -Value 'stale template content' -Encoding utf8

    $rejected = $false
    try {
        & $bootstrapPath -Target $mergeTarget | Out-Null
    } catch {
        $rejected = $true
    }
    Assert-Condition -Condition $rejected -Message 'Non-empty target was not rejected without -Force.'

    & $bootstrapPath -Target $mergeTarget -Force | Out-Null
    Assert-PathExists -Path $keepFile
    Assert-Condition -Condition ((Get-Content -Raw -LiteralPath $keepFile) -match 'preserve') -Message 'Existing user file was not preserved during -Force merge.'
    Assert-Condition -Condition ((Get-Content -Raw -LiteralPath $outlinePath) -match 'manifest/vault-manifest.json') -Message 'Generated outline was not refreshed during -Force merge.'
    Assert-Condition -Condition ((Get-Content -Raw -LiteralPath $templatePath) -notmatch 'stale template content') -Message 'Generated template was not refreshed during -Force merge.'

    Write-Output "Smoke tests passed: $assertions assertions."
} finally {
    if (-not $KeepTemp -and (Test-Path -LiteralPath $tempRoot)) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        $resolvedSystemTemp = [System.IO.Path]::GetFullPath($env:TEMP)
        if ($resolvedTempRoot.StartsWith($resolvedSystemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and $resolvedTempRoot -like '*knowledge-workspace-smoke-*') {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
        } else {
            throw "Refusing to remove unexpected temporary path: $resolvedTempRoot"
        }
    } elseif ($KeepTemp) {
        Write-Output "Temporary test workspace kept at: $tempRoot"
    }
}
