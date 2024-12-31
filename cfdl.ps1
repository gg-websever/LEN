# 检查是否以管理员身份运行
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "请以管理员身份运行此脚本。" -ForegroundColor Red
    exit 1
}

# 函数：下载文件
function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath
    )
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
}

# 检查 Node.js 是否安装
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "未检测到 Node.js，正在下载并安装 Node.js..." -ForegroundColor Yellow

    # 定义 Node.js 安装包
    $nodeInstaller = "node-v16.20.1-x64.msi"
    $nodeUrl = "https://nodejs.org/dist/v16.20.1/$nodeInstaller"
    $installerPath = "$env:TEMP\$nodeInstaller"

    # 下载 Node.js
    Download-File -Url $nodeUrl -OutputPath $installerPath

    # 安装 Node.js
    Start-Process msiexec.exe -ArgumentList "/i $installerPath /quiet /norestart" -Wait
    if ($LASTEXITCODE -ne 0) {
        Write-Host "执行完成请重启PowerShell。" -ForegroundColor Red
        exit 1
    }

    Write-Host "Node.js 安装成功。" -ForegroundColor Green
}

# 检查是否安装了 JavaScript Obfuscator
if (-not (npm list -g javascript-obfuscator | Select-String "javascript-obfuscator")) {
    Write-Host "正在安装 JavaScript Obfuscator..." -ForegroundColor Yellow
    npm install -g javascript-obfuscator
    if ($LASTEXITCODE -ne 0) {
        Write-Host "JavaScript Obfuscator 安装失败。" -ForegroundColor Red
        exit 1
    }
    Write-Host "JavaScript Obfuscator 安装成功。" -ForegroundColor Green
}

# 下载文件到临时文件夹
$tempDir = [System.IO.Path]::GetTempPath()
$inputFile = Join-Path $tempDir "index.js"
$outputFile = "$PSScriptRoot\_worker.js"
$backupFile = Join-Path $tempDir "index.bak"

Write-Host "正在从远程下载文件..."
$sourceUrl = "https://joeyblog.net/jb/index.js"
Download-File -Url $sourceUrl -OutputPath $inputFile
if (-not (Test-Path $inputFile)) {
    Write-Host "文件下载失败，请检查 URL 或网络连接。" -ForegroundColor Red
    exit 1
}

# 强制读取文件为 UTF-8
$fileContent = Get-Content $inputFile -Raw -Encoding UTF8

# 交互：输入 UUID
$uuid = Read-Host "请输入一个 UUID（不填自动生成）"

# 如果用户未输入 UUID，则自动生成一个
if (-not $uuid) {
    $uuid = [guid]::NewGuid().ToString()
    Write-Host "未输入 UUID，自动生成：$uuid" -ForegroundColor Yellow
}

# 检查输入是否是有效的 UUID
if ($uuid -notmatch "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$") {
    Write-Host "输入的 UUID 格式无效，请重新运行脚本并输入正确的 UUID。" -ForegroundColor Red
    exit 1
}

# 交互：输入伪装域名
$fakedomain = Read-Host "请输入伪装域名（不填使用 example）"

# 如果未输入伪装域名，设置默认值
if (-not $fakedomain) {
    $fakedomain = "example.com"
    Write-Host "未输入伪装域名，使用默认值: $fakedomain" -ForegroundColor Yellow
}

# 检查用户是否输入伪装域名
if (-not $fakedomain) {
    Write-Host "未输入伪装域名，操作中止。" -ForegroundColor Red
    exit 1
}

# 替换文件中的指定字符串并保存为 UTF-8
try {
    
    # 替换内容
    $fileContent = $fileContent -replace [regex]::Escape("bb9784ed-18c8-4ade-89c0-9bc1495bb6e0"), $uuid
    $fileContent = $fileContent -replace [regex]::Escape("example.com"), $fakedomain

    # 保存替换后的文件
    Set-Content -Path $inputFile -Value $fileContent -Encoding UTF8
} catch {
    Write-Host "替换过程中出现错误：" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# 执行代码生成
Write-Host "正在生成代码..."
javascript-obfuscator $inputFile --output $outputFile `
    --compact true `
    --control-flow-flattening true `
    --control-flow-flattening-threshold 1 `
    --dead-code-injection true `
    --dead-code-injection-threshold 1 `
    --identifier-names-generator hexadecimal `
    --rename-globals true `
    --string-array true `
    --string-array-encoding 'rc4' `
    --string-array-threshold 1 `
    --transform-object-keys true `
    --unicode-escape-sequence true

if ($LASTEXITCODE -ne 0) {
    Write-Host "代码生成失败。" -ForegroundColor Red
    exit 1
}

# 提示生成完成
Write-Host "代码生成完成，输出文件：$outputFile" -ForegroundColor Green
Remove-Item -Path $MyInvocation.MyCommand.Path

