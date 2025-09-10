# 运行鸿蒙一键构建部署脚本（单模块模式）- Windows PowerShell版本
# 使用前请确保 hdc 已连接设备，DevEco Studio 工具链已安装

# ================== 可配置变量 ==================
# 项目包名(根据实际项目包名修改!!!!!)  
$BUNDLE_NAME = "com.wss.myapplication"
# ================== 可配置变量 ==================

# ================== 固定的变量 ==================
# 临时目录名（使用随机字符串避免冲突）
$TMP_DIR = "hm_deploy_tmp_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
# HAP 包路径（构建后将自动探测最新的 .hap 文件）
$ENTRY_HAP = ""
# ================== 固定的变量 ==================

# 设置错误时停止执行
$ErrorActionPreference = "Stop"

function Find-HapFile {
  <#
    .SYNOPSIS
    Auto find the latest generated .hap file under entry\build directory.
    .DESCRIPTION
    Different OpenHarmony/DevEco versions may output .hap to different paths (e.g., outputs\default\app\entry-default.hap or outputs\default\entry-default-unsigned.hap).
    This function recursively searches all .hap files under entry\build and returns the most recently modified one.
    .OUTPUTS
    string - the full path to the latest .hap file; throws if none found.
  #>
  $buildDir = Join-Path $PSScriptRoot "entry\build"
  if (-not (Test-Path $buildDir)) {
    throw "Build directory not found: $buildDir"
  }
  $haps = Get-ChildItem -Path $buildDir -Recurse -Filter *.hap -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if (-not $haps -or $haps.Count -eq 0) {
    throw "No .hap artifact found under: $buildDir. Make sure build succeeded."
  }
  return $haps[0].FullName
}

try {
    Write-Host '1) Install dependencies...' -ForegroundColor Green
    ohpm install --all --registry https://ohpm.openharmony.cn/ohpm/ --strict_ssl true
    Write-Host '   Note: Ensure all dependencies are installed to avoid build failures.' -ForegroundColor DarkGray

    Write-Host '2) Build project...' -ForegroundColor Green
    hvigorw assembleApp
    Write-Host '   Note: Run standard assemble task to generate .hap artifacts.' -ForegroundColor DarkGray

    # Locate .hap in case .app packaging requires Java which may be missing in PATH
    Write-Host '3) Locate HAP artifact...' -ForegroundColor Green
    $ENTRY_HAP = Find-HapFile
    Write-Host ("   Found HAP: {0}" -f $ENTRY_HAP) -ForegroundColor Cyan
    Write-Host '   Note: Compatible with different output directory structures.' -ForegroundColor DarkGray

    Write-Host '4) Stop running app...' -ForegroundColor Green
    try {
        hdc shell aa force-stop "$BUNDLE_NAME"
    } catch {
        Write-Host '   App not running or stop failed, continue...' -ForegroundColor Yellow
    }
    Write-Host '   Note: Avoid install conflicts by stopping the app.' -ForegroundColor DarkGray

    Write-Host '5) Install HAP...' -ForegroundColor Green
    hdc install -r "$ENTRY_HAP"
    Write-Host '   Note: Install via hdc directly to bypass .app packaging.' -ForegroundColor DarkGray

    Write-Host '6) Launch app...' -ForegroundColor Green
    hdc shell aa start -a EntryAbility -b "$BUNDLE_NAME" -m entry
    Write-Host '   Note: Verify installation and preview changes immediately.' -ForegroundColor DarkGray

    Write-Host 'Build & Deploy finished. App started.' -ForegroundColor Green

} catch {
    Write-Host ("Build & Deploy failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Please check error details and retry.' -ForegroundColor Red
    exit 1
}