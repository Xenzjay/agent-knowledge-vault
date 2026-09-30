[CmdletBinding()]
param(
    [string]$Path
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Join-Path $scriptRoot ".."
}
$root = [System.IO.Path]::GetFullPath($Path)
$files = Get-ChildItem -LiteralPath $root -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\.git\\' }

$issues = New-Object System.Collections.Generic.List[string]

function Add-Issue {
    param([string]$Message)
    $issues.Add($Message)
}

function Test-RequiredProperty {
    param(
        [object]$Object,
        [string]$Property,
        [string]$Context
    )
    $propertyValue = $Object.PSObject.Properties[$Property]
    if ($null -eq $propertyValue -or $null -eq $propertyValue.Value) {
        Add-Issue "Missing required manifest property [$Property] at $Context."
        return $false
    }
    return $true
}

function Test-SafeDirectoryName {
    param(
        [string]$Name,
        [string]$Context
    )
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Add-Issue "Empty directory name at $Context."
        return
    }
    if ($Name -in @('.', '..') -or $Name -match '[<>:"/\\|?*\x00-\x1F]' -or $Name.EndsWith('.') -or $Name.EndsWith(' ')) {
        Add-Issue "Unsafe directory name [$Name] at $Context."
        return
    }
    $reserved = 'CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]'
    if ($Name -match "^(?i:$reserved)(\..*)?$") {
        Add-Issue "Reserved Windows directory name [$Name] at $Context."
    }
}

function Add-UniqueIssue {
    param([string]$Message)
    if (-not $issues.Contains($Message)) {
        $issues.Add($Message)
    }
}

$manifestPath = Join-Path $root "manifest\vault-manifest.json"
$allowedTargets = New-Object System.Collections.Generic.HashSet[string]
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        $requiredRootProperties = @('version', 'name', 'language', 'defaultDepth', 'system', 'zones', 'rules')
        foreach ($property in $requiredRootProperties) {
            Test-RequiredProperty -Object $manifest -Property $property -Context 'manifest root' | Out-Null
        }

        if ($manifest.defaultDepth -ne 2) {
            Add-Issue "Manifest defaultDepth must be 2."
        }

        $systemNames = @()
        foreach ($systemItem in @($manifest.system)) {
            $context = "system item"
            $hasName = Test-RequiredProperty -Object $systemItem -Property 'name' -Context $context
            Test-RequiredProperty -Object $systemItem -Property 'purpose' -Context $context | Out-Null
            if ($hasName) {
                Test-SafeDirectoryName -Name ([string]$systemItem.name) -Context $context
                $systemNames += [string]$systemItem.name
            }
            if ($null -ne $systemItem.children) {
                $systemChildren = @($systemItem.children | Where-Object { $null -ne $_ })
                foreach ($child in $systemChildren) {
                    Test-SafeDirectoryName -Name ([string]$child) -Context "system [$($systemItem.name)] child"
                }
                if (@($systemChildren | Select-Object -Unique).Count -ne $systemChildren.Count) {
                    Add-Issue "Duplicate child directory in system [$($systemItem.name)]."
                }
            }
        }
        if (@($systemNames | Select-Object -Unique).Count -ne $systemNames.Count) {
            Add-Issue "Duplicate system directory name in vault manifest."
        }

        $zoneNames = @()
        foreach ($zone in @($manifest.zones)) {
            $zoneContext = "zone [$($zone.displayName)]"
            $hasDisplayName = Test-RequiredProperty -Object $zone -Property 'displayName' -Context 'zone'
            Test-RequiredProperty -Object $zone -Property 'name' -Context $zoneContext | Out-Null
            Test-RequiredProperty -Object $zone -Property 'purpose' -Context $zoneContext | Out-Null
            $hasCategories = Test-RequiredProperty -Object $zone -Property 'categories' -Context $zoneContext
            if ($hasDisplayName) {
                Test-SafeDirectoryName -Name ([string]$zone.displayName) -Context 'zone'
                $zoneNames += [string]$zone.displayName
            }
            if (-not $hasCategories) { continue }

            $categoryNames = @()
            foreach ($category in @($zone.categories)) {
                $categoryContext = "zone [$($zone.displayName)] category"
                $hasCategoryDisplayName = Test-RequiredProperty -Object $category -Property 'displayName' -Context $categoryContext
                Test-RequiredProperty -Object $category -Property 'name' -Context $categoryContext | Out-Null
                if ($hasCategoryDisplayName) {
                    Test-SafeDirectoryName -Name ([string]$category.displayName) -Context $categoryContext
                    $categoryNames += [string]$category.displayName
                    if ($hasDisplayName) {
                        [void]$allowedTargets.Add("$($zone.displayName)/$($category.displayName)")
                    }
                }
                $children = @($category.children | Where-Object { $null -ne $_ })
                if ($children.Count -gt 0) {
                    foreach ($child in $children) {
                        Test-SafeDirectoryName -Name ([string]$child) -Context "category [$($category.displayName)] child"
                    }
                    if (@($children | Select-Object -Unique).Count -ne $children.Count) {
                        Add-Issue "Duplicate subgroup in category [$($category.displayName)] of zone [$($zone.displayName)]."
                    }
                }
            }
            if ($categoryNames.Count -eq 0) {
                Add-Issue "Zone has no second-level categories: $($zone.displayName)"
            }
            if (@($categoryNames | Select-Object -Unique).Count -ne $categoryNames.Count) {
                Add-Issue "Duplicate category in zone: $($zone.displayName)"
            }
        }
        if (@($zoneNames | Select-Object -Unique).Count -ne $zoneNames.Count) {
            Add-Issue "Duplicate top-level displayName in vault manifest."
        }
    } catch {
        Add-Issue "Invalid vault manifest JSON: $($_.Exception.Message)"
    }
} else {
    Add-Issue "Missing manifest/vault-manifest.json"
}

$routingPath = Join-Path $root "manifest\routing-rules.yaml"
if (Test-Path -LiteralPath $routingPath) {
    $routingLines = Get-Content -LiteralPath $routingPath
    $ruleIds = @($routingLines | ForEach-Object {
        if ($_ -match '^\s*-\s+id:\s*(.+?)\s*$') { $matches[1].Trim().Trim('"', "'") }
    })
    if ($ruleIds.Count -eq 0) {
        Add-Issue "Routing manifest contains no rules."
    } elseif (@($ruleIds | Select-Object -Unique).Count -ne $ruleIds.Count) {
        Add-Issue "Duplicate routing rule id."
    }

    $routingTargets = @($routingLines | ForEach-Object {
        if ($_ -match '^\s*target:\s*(.+?)\s*$') { $matches[1].Trim().Trim('"', "'") }
    })
    foreach ($target in $routingTargets) {
        if (-not $allowedTargets.Contains($target)) {
            Add-Issue "Routing target does not match a manifest category: $target"
        }
    }
} else {
    Add-Issue "Missing manifest/routing-rules.yaml"
}

$secretPatterns = @(
    '(?i)api[_-]?key\s*[:=]\s*[A-Za-z0-9_\-]{12,}',
    '(?i)(password|passwd|secret|token)\s*[:=]\s*[^\s]{8,}',
    '(?i)-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)(sk|ghp|github_pat)_[A-Za-z0-9]{20,}',
    '(?i)[A-Z]:\\Users\\[^\\\s]+\\'
)

foreach ($file in $files) {
    $text = Get-Content -Raw -LiteralPath $file.FullName

    $frontmatterMatch = [regex]::Match($text, '(?s)\A---\s*\r?\n(.*?)\r?\n---')
    if ($file.Extension -eq ".md" -and $frontmatterMatch.Success) {
        $frontmatter = $frontmatterMatch.Groups[1].Value
        if ($frontmatter -notmatch '(?m)^tags:\s*$') {
            Add-Issue "Missing tags frontmatter: $($file.FullName)"
        }
    }

    foreach ($pattern in $secretPatterns) {
        if ($text -match $pattern) {
            Add-Issue "Potential sensitive pattern [$pattern]: $($file.FullName)"
        }
    }
}

if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Validation passed: $($files.Count) files scanned."
