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

    # Ensure Java (for signing) exists in PATH; try to detect common DevEco JDK locations if missing
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        #region Helper: Add-JavaPath
        <#
            .SYNOPSIS
                将指定JDK/JRE的bin目录临时注入到当前进程的PATH，并在未设置时推断JAVA_HOME。
            .DESCRIPTION
                - 校验传入的bin路径是否存在；
                - 将其前置添加到PATH，确保后续子进程能发现java.exe；
                - 若JAVA_HOME未设置，则以bin的上级目录作为JAVA_HOME；
                - 输出探测日志，便于诊断问题。
            .PARAMETER binPath
                期望加入PATH的JDK/JRE bin目录的绝对路径。
            .OUTPUTS
                [bool] True 表示成功注入，False 表示路径无效或注入失败。
            .NOTES
                脚本仅影响当前PowerShell会话，不会修改系统环境变量，安全可回退。
        #>
        function Add-JavaPath([string]$binPath) {
            if ($binPath -and (Test-Path $binPath)) {
                $env:PATH = "$binPath;$env:PATH"
                if (-not $env:JAVA_HOME) {
                    try { $env:JAVA_HOME = (Split-Path $binPath -Parent) } catch {}
                }
                Write-Host ("   Java detected via: {0}" -f $binPath) -ForegroundColor DarkGray
                return $true
            }
            return $false
        }
        #endregion

        $candidateBins = @(
            "D:\\DevEco Studio\\tools\\jdk\\bin",
            "D:\\DevEco Studio\\tools\\java\\openjdk\\bin",
            "C:\\DevEco Studio\\tools\\jdk\\bin",
            "C:\\DevEco Studio\\tools\\java\\openjdk\\bin",
            "C:\\Program Files\\Huawei\\DevEco Studio\\tools\\jdk\\bin",
            "C:\\Program Files\\Huawei\\DevEco Studio\\tools\\java\\openjdk\\bin",
            "D:\\Program Files\\Huawei\\DevEco Studio\\tools\\jdk\\bin",
            "D:\\Program Files\\Huawei\\DevEco Studio\\tools\\java\\openjdk\\bin",
            "$env:JAVA_HOME\\bin",
            "C:\\Program Files\\OpenJDK\\jdk-17\\bin",
            "C:\\Program Files\\Java\\jdk-17\\bin"
        )

        $added = $false
        foreach ($bin in $candidateBins) {
            if (Add-JavaPath -binPath $bin) { $added = $true; break }
        }

        # 最后兜底：在 DevEco Studio 目录下递归搜索 java.exe
        if (-not $added) {
            $searchRoots = @("D:\\DevEco Studio", "C:\\DevEco Studio", "C:\\Program Files\\Huawei\\DevEco Studio", "D:\\Program Files\\Huawei\\DevEco Studio")
            foreach ($root in $searchRoots) {
                if (Test-Path $root) {
                    $javaExe = Get-ChildItem -Path $root -Filter java.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($javaExe) {
                        $binPath = Split-Path $javaExe.FullName -Parent
                        if (Add-JavaPath -binPath $binPath) { $added = $true; break }
                    }
                }
            }
        }

        if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
            Write-Host '   Warning: Java not found in PATH. Packaging may produce unsigned HAP and installation can fail.' -ForegroundColor Yellow
        }
    }

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