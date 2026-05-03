param(
    [int]$Days = 7,
    [int]$Limit = 5,
    [switch]$Sample
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ReadmePath = Join-Path $Root "README.md"
$ReportsDir = Join-Path $Root "reports"

$Categories = @(
    @{ Name = "AI / LLM"; Query = "topic:ai OR topic:llm OR topic:generative-ai" },
    @{ Name = "Developer Tools"; Query = "topic:developer-tools OR topic:cli OR topic:devtools" },
    @{ Name = "Frontend"; Query = "topic:frontend OR topic:react OR topic:vue OR topic:nextjs" },
    @{ Name = "Backend"; Query = "topic:backend OR topic:api OR topic:server" },
    @{ Name = "Python"; Query = "language:Python" },
    @{ Name = "Go"; Query = "language:Go" },
    @{ Name = "Rust"; Query = "language:Rust" }
)

$SampleRepos = @(
    [pscustomobject]@{
        full_name = "example/awesome-ai-tool"
        html_url = "https://github.com/example/awesome-ai-tool"
        description = "A sample AI developer tool used for offline report previews."
        stargazers_count = 12345
        forks_count = 678
        language = "Python"
        pushed_at = "2026-05-03T00:00:00Z"
    },
    [pscustomobject]@{
        full_name = "example/fast-web-framework"
        html_url = "https://github.com/example/fast-web-framework"
        description = "A sample framework entry for local smoke tests."
        stargazers_count = 9876
        forks_count = 321
        language = "Rust"
        pushed_at = "2026-05-02T00:00:00Z"
    }
)

function Get-GitHubHeaders {
    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "github-weekly-trending-report"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $token = $env:GH_TOKEN
    if (-not $token) {
        $token = $env:GITHUB_TOKEN
    }
    if ($token) {
        $headers["Authorization"] = "Bearer $token"
    }
    return $headers
}

function Search-Repositories {
    param(
        [string]$Query,
        [int]$Top
    )

    $encoded = [uri]::EscapeDataString($Query)
    $url = "https://api.github.com/search/repositories?q=$encoded&sort=stars&order=desc&per_page=$Top"
    $result = Invoke-RestMethod -Uri $url -Headers (Get-GitHubHeaders) -Method Get
    return @($result.items | Select-Object -First $Top)
}

function Format-RepoLine {
    param($Repo)

    $description = $Repo.description
    if (-not $description) {
        $description = "No description."
    }
    $description = ($description -replace "\s+", " ").Trim()
    $language = $Repo.language
    if (-not $language) {
        $language = "Unknown"
    }
    $pushed = ""
    if ($Repo.pushed_at) {
        $pushed = $Repo.pushed_at.ToString().Substring(0, 10)
    }
    return "- [$($Repo.full_name)]($($Repo.html_url)) - $description | stars $($Repo.stargazers_count) | forks $($Repo.forks_count) | $language | pushed $pushed"
}

$Since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-dd")
$Now = (Get-Date).ToUniversalTime()
$GeneratedAt = $Now.ToString("yyyy-MM-dd HH:mm 'UTC'")
$DateStamp = $Now.ToString("yyyy-MM-dd")

$Lines = New-Object System.Collections.Generic.List[string]
$Lines.Add("# GitHub Weekly Trending Report")
$Lines.Add("")
$Lines.Add("Generated at: $GeneratedAt")
$Lines.Add("Lookback window: last $Days days")
$Lines.Add("")
$Lines.Add("Note: New hot is sorted by stars among recently created repositories. Active hot is sorted by stars among recently pushed repositories.")
$Lines.Add("")

foreach ($category in $Categories) {
    if ($Sample) {
        $newRepos = @($SampleRepos | Select-Object -First $Limit)
        $activeRepos = @($SampleRepos | Select-Object -First $Limit)
    }
    else {
        $newQuery = "($($category.Query)) created:>=$Since stars:>5"
        $activeQuery = "($($category.Query)) pushed:>=$Since stars:>500"
        $newRepos = Search-Repositories -Query $newQuery -Top $Limit
        $activeRepos = Search-Repositories -Query $activeQuery -Top $Limit
    }

    $Lines.Add("## $($category.Name)")
    $Lines.Add("")
    $Lines.Add("### New hot")
    $Lines.Add("")
    if ($newRepos.Count -gt 0) {
        foreach ($repo in $newRepos) {
            $Lines.Add((Format-RepoLine -Repo $repo))
        }
    }
    else {
        $Lines.Add("- No matching repositories.")
    }
    $Lines.Add("")
    $Lines.Add("### Active hot")
    $Lines.Add("")
    if ($activeRepos.Count -gt 0) {
        foreach ($repo in $activeRepos) {
            $Lines.Add((Format-RepoLine -Repo $repo))
        }
    }
    else {
        $Lines.Add("- No matching repositories.")
    }
    $Lines.Add("")
}

$Lines.Add("## Local usage")
$Lines.Add("")
$Lines.Add("    .\scripts\generate_trending.ps1")
$Lines.Add("")
$Lines.Add("Optional: set GH_TOKEN or GITHUB_TOKEN to increase the GitHub API rate limit.")
$Lines.Add("")

New-Item -ItemType Directory -Force -Path $ReportsDir | Out-Null
$Markdown = $Lines -join "`n"
$ReportPath = Join-Path $ReportsDir "$DateStamp.md"
[System.IO.File]::WriteAllText($ReadmePath, $Markdown, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($ReportPath, $Markdown, [System.Text.Encoding]::UTF8)

Write-Host "Wrote README.md"
Write-Host "Wrote reports/$DateStamp.md"
