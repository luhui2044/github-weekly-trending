#!/usr/bin/env python3
"""Generate a weekly GitHub trending report.

The script writes two files:
- README.md: latest report for the repository front page
- reports/YYYY-MM-DD.md: archived weekly report

It uses only the Python standard library. Set GH_TOKEN or GITHUB_TOKEN to
increase the GitHub API rate limit.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import textwrap
import urllib.error
import urllib.parse
import urllib.request


ROOT = pathlib.Path(__file__).resolve().parents[1]
README_PATH = ROOT / "README.md"
REPORTS_DIR = ROOT / "reports"

CATEGORIES = [
    ("AI / LLM", "topic:ai OR topic:llm OR topic:generative-ai"),
    ("开发者工具", "topic:developer-tools OR topic:cli OR topic:devtools"),
    ("前端", "topic:frontend OR topic:react OR topic:vue OR topic:nextjs"),
    ("后端", "topic:backend OR topic:api OR topic:server"),
    ("Python", "language:Python"),
    ("Go", "language:Go"),
    ("Rust", "language:Rust"),
]

SAMPLE_REPOS = [
    {
        "full_name": "example/awesome-ai-tool",
        "html_url": "https://github.com/example/awesome-ai-tool",
        "description": "A sample AI developer tool used for offline report previews.",
        "stargazers_count": 12345,
        "forks_count": 678,
        "language": "Python",
        "pushed_at": "2026-05-03T00:00:00Z",
        "topics": ["ai", "developer-tools"],
    },
    {
        "full_name": "example/fast-web-framework",
        "html_url": "https://github.com/example/fast-web-framework",
        "description": "A sample framework entry for local smoke tests.",
        "stargazers_count": 9876,
        "forks_count": 321,
        "language": "Rust",
        "pushed_at": "2026-05-02T00:00:00Z",
        "topics": ["web", "framework"],
    },
]


def iso_date(days_back: int) -> str:
    return (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days_back)).date().isoformat()


def github_headers() -> dict[str, str]:
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "github-weekly-trending-report",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def search_repositories(query: str, limit: int) -> list[dict]:
    params = urllib.parse.urlencode(
        {
            "q": query,
            "sort": "stars",
            "order": "desc",
            "per_page": str(limit),
        }
    )
    url = f"https://api.github.com/search/repositories?{params}"
    request = urllib.request.Request(url, headers=github_headers())
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API error {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error while calling GitHub API: {exc}") from exc
    return payload.get("items", [])[:limit]


def clean_text(value: str | None, fallback: str = "暂无项目描述。") -> str:
    text = value or fallback
    return " ".join(text.split())


def infer_profile(repo: dict, category: str) -> tuple[str, str]:
    description = clean_text(repo.get("description"), "")
    language = repo.get("language") or "Unknown"
    topics = [str(topic).lower() for topic in repo.get("topics", [])]
    haystack = " ".join([description.lower(), language.lower(), category.lower(), *topics])

    if any(key in haystack for key in ["llm", "ai", "agent", "rag", "chatgpt", "model", "inference"]):
        feature = "围绕 AI/LLM 能力构建，重点解决模型调用、智能体编排、知识检索、推理服务或自动化工作流等问题。"
        scenario = "适合用于智能助手、企业知识库、研发自动化、AI 原型验证、模型应用集成等场景。"
    elif any(key in haystack for key in ["cli", "developer", "devtools", "tool", "terminal", "debug"]):
        feature = "面向开发者效率提升，通常提供命令行工具、调试辅助、工程自动化、代码生成或本地开发体验优化。"
        scenario = "适合用于团队研发流程、CI/CD 辅助、本地开发提效、代码质量治理和工程脚手架建设。"
    elif any(key in haystack for key in ["react", "vue", "frontend", "ui", "css", "nextjs", "component"]):
        feature = "聚焦前端界面与交互开发，常见特点是组件化、工程化、可视化呈现或现代 Web 应用体验优化。"
        scenario = "适合用于管理后台、SaaS 产品、官网、可视化大屏、交互式工具和前端组件库建设。"
    elif any(key in haystack for key in ["api", "server", "backend", "database", "cloud", "kubernetes", "microservice"]):
        feature = "偏向后端服务与基础设施能力，通常关注 API、数据处理、服务治理、云原生部署或系统性能。"
        scenario = "适合用于业务后端、平台服务、微服务治理、数据接口、云原生应用和企业级系统集成。"
    elif language == "Go":
        feature = "以 Go 语言实现，通常强调高并发、部署简单、性能稳定和服务端工程实践。"
        scenario = "适合用于后端服务、网络工具、云原生组件、运维平台和高性能命令行工具。"
    elif language == "Rust":
        feature = "以 Rust 语言实现，通常强调内存安全、运行性能、可靠性和系统级能力。"
        scenario = "适合用于系统工具、性能敏感服务、开发者工具、嵌入式或安全要求较高的工程。"
    elif language == "Python":
        feature = "以 Python 生态为主，通常便于快速实验、自动化脚本、数据处理、AI 应用或服务原型开发。"
        scenario = "适合用于数据分析、机器学习、自动化任务、后端脚本、研究原型和内部效率工具。"
    else:
        feature = "该项目近期热度较高，主要价值可从仓库描述、语言生态、活跃度和社区关注度进一步判断。"
        scenario = "适合先作为技术调研对象，用于评估是否能引入到个人项目、团队工具链或产品原型中。"

    return feature, scenario


def repo_block(repo: dict, category: str) -> list[str]:
    name = repo.get("full_name", "unknown/repo")
    url = repo.get("html_url", "")
    description = clean_text(repo.get("description"))
    stars = repo.get("stargazers_count", 0)
    forks = repo.get("forks_count", 0)
    language = repo.get("language") or "Unknown"
    pushed_at = (repo.get("pushed_at") or "")[:10]
    feature, scenario = infer_profile(repo, category)
    return [
        f"- [{name}]({url})",
        f"  - 项目描述：{description}",
        f"  - 功能特点：{feature}",
        f"  - 典型场景：{scenario}",
        f"  - 热度指标：`stars {stars}` `forks {forks}` `{language}` `最近推送 {pushed_at}`",
    ]


def collect_report(days: int, limit: int, sample: bool) -> dict[str, dict[str, list[dict]]]:
    since = iso_date(days)
    report: dict[str, dict[str, list[dict]]] = {}
    for category, topic_query in CATEGORIES:
        if sample:
            new_repos = SAMPLE_REPOS[:limit]
            active_repos = list(reversed(SAMPLE_REPOS[:limit]))
        else:
            new_query = f"({topic_query}) created:>={since} stars:>5"
            active_query = f"({topic_query}) pushed:>={since} stars:>500"
            new_repos = search_repositories(new_query, limit)
            active_repos = search_repositories(active_query, limit)
        report[category] = {
            "new": new_repos,
            "active": active_repos,
        }
    return report


def render_markdown(report: dict[str, dict[str, list[dict]]], days: int, generated_at: str) -> str:
    lines = [
        "# GitHub 热门项目周报",
        "",
        f"生成时间：`{generated_at}`",
        f"统计窗口：最近 `{days}` 天",
        "",
        "说明：`新晋热门` 按最近创建且 star 较高的仓库排序；`活跃热门` 按最近推送且总 star 较高的仓库排序。",
        "每个项目的功能特点和典型场景由仓库描述、语言和 topic 规则化归纳生成，用于快速筛选，深度采用前建议继续查看源码和文档。",
        "",
    ]

    for category, groups in report.items():
        lines.extend([f"## {category}", "", "### 新晋热门", ""])
        if groups["new"]:
            for repo in groups["new"]:
                lines.extend(repo_block(repo, category))
        else:
            lines.append("- 暂无匹配项目。")
        lines.extend(["", "### 活跃热门", ""])
        if groups["active"]:
            for repo in groups["active"]:
                lines.extend(repo_block(repo, category))
        else:
            lines.append("- 暂无匹配项目。")
        lines.append("")

    lines.extend(
        [
            "## 本地运行",
            "",
            "```bash",
            "python scripts/generate_trending.py",
            "```",
            "",
            "可选：设置 `GH_TOKEN` 或 `GITHUB_TOKEN` 以提高 GitHub API 额度。",
            "",
        ]
    )
    return "\n".join(lines)


def write_report(markdown: str, date_stamp: str) -> pathlib.Path:
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report_path = REPORTS_DIR / f"{date_stamp}.md"
    README_PATH.write_text(markdown, encoding="utf-8")
    report_path.write_text(markdown, encoding="utf-8")
    return report_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate README.md and reports/YYYY-MM-DD.md with hot GitHub repositories.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """\
            Examples:
              python scripts/generate_trending.py
              python scripts/generate_trending.py --days 14 --limit 8
              python scripts/generate_trending.py --sample
            """
        ),
    )
    parser.add_argument("--days", type=int, default=7, help="Lookback window in days.")
    parser.add_argument("--limit", type=int, default=5, help="Repositories per section.")
    parser.add_argument("--sample", action="store_true", help="Generate an offline sample report.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    now = dt.datetime.now(dt.timezone.utc)
    generated_at = now.strftime("%Y-%m-%d %H:%M UTC")
    date_stamp = now.date().isoformat()
    report = collect_report(days=args.days, limit=args.limit, sample=args.sample)
    markdown = render_markdown(report, days=args.days, generated_at=generated_at)
    report_path = write_report(markdown, date_stamp=date_stamp)
    print(f"Wrote {README_PATH.relative_to(ROOT)}")
    print(f"Wrote {report_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
