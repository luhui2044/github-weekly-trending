# GitHub 热门项目周报

这个仓库用于每周自动生成 GitHub 热门项目周报，并把结果写入仓库文件和本地 Markdown 文件。

## 本地生成

Windows PowerShell：

```powershell
.\scripts\generate_trending.ps1
```

如果本地安装了 Python：

```bash
python scripts/generate_trending.py
```

生成结果会写入：

- `README.md`
- `reports/YYYY-MM-DD.md`

建议先设置 GitHub Token，避免匿名 API 额度不足：

```powershell
$env:GH_TOKEN="你的 GitHub token"
.\scripts\generate_trending.ps1
```

## GitHub 自动更新

推送到 GitHub 后，`.github/workflows/weekly-trending.yml` 会在每周一北京时间 09:00 自动运行，并提交最新周报。

也可以在 GitHub Actions 页面手动点击 `Run workflow` 立即生成。
