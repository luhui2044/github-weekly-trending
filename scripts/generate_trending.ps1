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
    @{ Name = "开发者工具"; Query = "topic:developer-tools OR topic:cli OR topic:devtools" },
    @{ Name = "前端"; Query = "topic:frontend OR topic:react OR topic:vue OR topic:nextjs" },
    @{ Name = "后端"; Query = "topic:backend OR topic:api OR topic:server" },
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
        topics = @("ai", "developer-tools")
    },
    [pscustomobject]@{
        full_name = "example/fast-web-framework"
        html_url = "https://github.com/example/fast-web-framework"
        description = "A sample framework entry for local smoke tests."
        stargazers_count = 9876
        forks_count = 321
        language = "Rust"
        pushed_at = "2026-05-02T00:00:00Z"
        topics = @("web", "framework")
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

function Clean-Text {
    param(
        [string]$Text,
        [string]$Fallback = "暂无项目描述。"
    )
    if (-not $Text) {
        $Text = $Fallback
    }
    return (($Text -replace "\s+", " ").Trim())
}

function Test-AnyKeyword {
    param(
        [string]$Text,
        [string[]]$Keywords
    )
    foreach ($keyword in $Keywords) {
        if ($Text.Contains($keyword)) {
            return $true
        }
    }
    return $false
}

function Get-RepoProfile {
    param(
        $Repo,
        [string]$Category
    )

    $description = (Clean-Text -Text $Repo.description -Fallback "").ToLower()
    $language = $Repo.language
    if (-not $language) {
        $language = "Unknown"
    }
    $topicText = ""
    if ($Repo.topics) {
        $topicText = ($Repo.topics -join " ").ToLower()
    }
    $haystack = "$description $($language.ToLower()) $($Category.ToLower()) $topicText"

    $isAiTopic = $false
    if ($Repo.topics) {
        $isAiTopic = @($Repo.topics) -contains "ai"
    }
    if ($Category -eq "AI / LLM" -or $isAiTopic -or (Test-AnyKeyword -Text $haystack -Keywords @("llm", "agent", "rag", "chatgpt", "model", "inference"))) {
        return @{
            Feature = "围绕 AI/LLM 能力构建，重点解决模型调用、智能体编排、知识检索、推理服务或自动化工作流等问题。"
            Scenario = "适合用于智能助手、企业知识库、研发自动化、AI 原型验证、模型应用集成等场景。"
        }
    }
    if (Test-AnyKeyword -Text $haystack -Keywords @("cli", "developer", "devtools", "tool", "terminal", "debug", "language server", "type checker", "linter", "formatter", "compiler")) {
        return @{
            Feature = "面向开发者效率提升，通常提供命令行工具、调试辅助、工程自动化、代码生成或本地开发体验优化。"
            Scenario = "适合用于团队研发流程、CI/CD 辅助、本地开发提效、代码质量治理和工程脚手架建设。"
        }
    }
    if (Test-AnyKeyword -Text $haystack -Keywords @("react", "vue", "frontend", "ui", "css", "nextjs", "component")) {
        return @{
            Feature = "聚焦前端界面与交互开发，常见特点是组件化、工程化、可视化呈现或现代 Web 应用体验优化。"
            Scenario = "适合用于管理后台、SaaS 产品、官网、可视化大屏、交互式工具和前端组件库建设。"
        }
    }
    if (Test-AnyKeyword -Text $haystack -Keywords @("api", "server", "backend", "database", "cloud", "kubernetes", "microservice")) {
        return @{
            Feature = "偏向后端服务与基础设施能力，通常关注 API、数据处理、服务治理、云原生部署或系统性能。"
            Scenario = "适合用于业务后端、平台服务、微服务治理、数据接口、云原生应用和企业级系统集成。"
        }
    }
    if ($language -eq "Go") {
        return @{
            Feature = "以 Go 语言实现，通常强调高并发、部署简单、性能稳定和服务端工程实践。"
            Scenario = "适合用于后端服务、网络工具、云原生组件、运维平台和高性能命令行工具。"
        }
    }
    if ($language -eq "Rust") {
        return @{
            Feature = "以 Rust 语言实现，通常强调内存安全、运行性能、可靠性和系统级能力。"
            Scenario = "适合用于系统工具、性能敏感服务、开发者工具、嵌入式或安全要求较高的工程。"
        }
    }
    if ($language -eq "Python") {
        return @{
            Feature = "以 Python 生态为主，通常便于快速实验、自动化脚本、数据处理、AI 应用或服务原型开发。"
            Scenario = "适合用于数据分析、机器学习、自动化任务、后端脚本、研究原型和内部效率工具。"
        }
    }
    return @{
        Feature = "该项目近期热度较高，主要价值可从仓库描述、语言生态、活跃度和社区关注度进一步判断。"
        Scenario = "适合先作为技术调研对象，用于评估是否能引入到个人项目、团队工具链或产品原型中。"
    }
}

function Add-RepoBlock {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        $Repo,
        [string]$Category
    )

    $description = Clean-Text -Text $Repo.description
    $language = $Repo.language
    if (-not $language) {
        $language = "Unknown"
    }
    $pushed = ""
    if ($Repo.pushed_at) {
        $pushed = $Repo.pushed_at.ToString().Substring(0, 10)
    }
    $profile = Get-RepoProfile -Repo $Repo -Category $Category

    $Lines.Add("- [$($Repo.full_name)]($($Repo.html_url))")
    $Lines.Add("  - 项目描述：$description")
    $Lines.Add("  - 功能特点：$($profile.Feature)")
    $Lines.Add("  - 典型场景：$($profile.Scenario)")
    $Lines.Add("  - 热度指标：``stars $($Repo.stargazers_count)`` ``forks $($Repo.forks_count)`` ``$language`` ``最近推送 $pushed``")
}

$Since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-dd")
$Now = (Get-Date).ToUniversalTime()
$GeneratedAt = $Now.ToString("yyyy-MM-dd HH:mm 'UTC'")
$DateStamp = $Now.ToString("yyyy-MM-dd")

$Lines = New-Object System.Collections.Generic.List[string]
$Lines.Add("# GitHub 热门项目周报")
$Lines.Add("")
$Lines.Add("生成时间：``$GeneratedAt``")
$Lines.Add("统计窗口：最近 ``$Days`` 天")
$Lines.Add("")
$Lines.Add("说明：``新晋热门`` 按最近创建且 star 较高的仓库排序；``活跃热门`` 按最近推送且总 star 较高的仓库排序。")
$Lines.Add("每个项目的功能特点和典型场景由仓库描述、语言和 topic 规则化归纳生成，用于快速筛选，深度采用前建议继续查看源码和文档。")
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
    $Lines.Add("### 新晋热门")
    $Lines.Add("")
    if ($newRepos.Count -gt 0) {
        foreach ($repo in $newRepos) {
            Add-RepoBlock -Lines $Lines -Repo $repo -Category $category.Name
        }
    }
    else {
        $Lines.Add("- 暂无匹配项目。")
    }
    $Lines.Add("")
    $Lines.Add("### 活跃热门")
    $Lines.Add("")
    if ($activeRepos.Count -gt 0) {
        foreach ($repo in $activeRepos) {
            Add-RepoBlock -Lines $Lines -Repo $repo -Category $category.Name
        }
    }
    else {
        $Lines.Add("- 暂无匹配项目。")
    }
    $Lines.Add("")
}

$Lines.Add("## 本地运行")
$Lines.Add("")
$Lines.Add("    .\scripts\generate_trending.ps1")
$Lines.Add("")
$Lines.Add("可选：设置 GH_TOKEN 或 GITHUB_TOKEN 以提高 GitHub API 额度。")
$Lines.Add("")

New-Item -ItemType Directory -Force -Path $ReportsDir | Out-Null
$Markdown = $Lines -join "`n"
$ReportPath = Join-Path $ReportsDir "$DateStamp.md"
[System.IO.File]::WriteAllText($ReadmePath, $Markdown, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($ReportPath, $Markdown, [System.Text.Encoding]::UTF8)

Write-Host "Wrote README.md"
Write-Host "Wrote reports/$DateStamp.md"
