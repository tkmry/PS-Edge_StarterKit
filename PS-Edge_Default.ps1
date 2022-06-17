Param(
    [switch]$Init
)

Add-Type -AssemblyName PresentationFramework  # WPF 用
Add-Type -AssemblyName System.Windows.Forms   # Timer 用

$libWebView2Wpf    = (Join-Path $PSScriptRoot "lib\Microsoft.Web.WebView2.Wpf.dll")
$libWebView2Core   = (Join-Path $PSScriptRoot "lib\Microsoft.Web.WebView2.Core.dll")
$libWebview2Loader = (Join-Path $PSScriptRoot "lib\WebView2Loader.dll")

if ($Init) {
    # 初期セットアップ用の処理
    Write-Host "WebView2 ライブラリ取得を行います。既に取得している場合は一度削除し再取得します。"

    if (Test-Path "lib") {
        Remove-Item "lib" -Recurse
    }

    Find-Package -Name  Microsoft.Web.WebView2 -Source https://www.nuget.org/api/v2 | Save-Package -Path $PSScriptRoot
    $nugetFile    = Get-Item *.nupkg
    $nugetZipFile = $nugetFile.FullName + ".zip"
    Rename-Item $nugetFile $nugetZipFile
    Expand-Archive $nugetZipFile

    if (-not (Test-Path "lib")) {
        New-Item -type Directory "lib"
    }
    Copy-Item (Join-Path $nugetFile "\lib\net45\Microsoft.Web.WebView2.Core.dll") "lib"
    Copy-Item (Join-Path $nugetFile "\lib\net45\Microsoft.Web.WebView2.Wpf.dll") "lib"
    Copy-Item (Join-Path $nugetFile "\runtimes\win-x64\native\WebView2Loader.dll") "lib"

    Remove-Item $nugetFile -Recurse
    Remove-Item $nugetZipFile

    if ((Test-Path $libWebView2Wpf) -and (Test-Path $libWebView2Core) -and (Test-Path $libWebview2Loader)) {
        Read-Host "取得に成功しました[Enter]"
        exit 0
    }
    else {
        Read-Host "取得に失敗しました[Enter]"
        exit 1
    }
}

<# WebView2 用アセンブリロード #>
[void][reflection.assembly]::LoadFile($libWebView2Wpf)
[void][reflection.assembly]::LoadFile($libWebView2Core)

<# XAML にて Window 構築 #>
[xml]$xaml  = (Get-Content (Join-Path $PSScriptRoot "ui01.xaml"))
$nodeReader = (New-Object System.XML.XmlNodeReader $xaml)
$window     = [Windows.Markup.XamlReader]::Load($nodeReader)

<# WebView2 の設定 #>
$webview = $window.findName("webView")
$webview.CreationProperties = New-Object 'Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties'
$webview.CreationProperties.UserDataFolder = (Join-Path $PSScriptRoot "data")


<# Window の表示 #>
[void]$window.ShowDialog()
$window.Close()
