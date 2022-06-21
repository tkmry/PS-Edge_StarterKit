Param(
    [switch]$Init
)

Add-Type -AssemblyName PresentationFramework  # WPF 用
Add-Type -AssemblyName System.Windows.Forms   # Timer 用

$libWebView2Wpf    = (Join-Path $PSScriptRoot "lib\Microsoft.Web.WebView2.Wpf.dll")
$libWebView2Core   = (Join-Path $PSScriptRoot "lib\Microsoft.Web.WebView2.Core.dll")
$libWebview2Loader = (Join-Path $PSScriptRoot "lib\WebView2Loader.dll")

if ($Init) {
    # init.bat の実行時の動作(初期セットアップ用の処理)
    Write-Host "WebView2 ライブラリ取得を行います。既に取得している場合は一度削除し再取得します。"

    if (Test-Path "lib") {
        Write-Host "既に lib フォルダが存在する為削除します。"
        Remove-Item "lib" -Recurse
    }

    Write-Host "WebView2 パッケージを取得します。"
    Find-Package -Name  Microsoft.Web.WebView2 -Source https://www.nuget.org/api/v2 | Save-Package -Path $PSScriptRoot > $null
    $nugetFile    = Get-Item *.nupkg
    $nugetZipFile = $nugetFile.FullName + ".zip"

    Write-Host "WebView2 パッケージを展開します。"
    Rename-Item $nugetFile $nugetZipFile
    Expand-Archive $nugetZipFile > $null

    if (-not (Test-Path "lib")) {
        Write-Host "lib フォルダ(WebView2) フォルダの格納先を作成します。"
        New-Item -type Directory "lib" > $null
    }
    Write-Host "WebView2で利用するdllを配置します。"
    Copy-Item (Join-Path $nugetFile "\lib\net45\Microsoft.Web.WebView2.Core.dll") "lib"
    Copy-Item (Join-Path $nugetFile "\lib\net45\Microsoft.Web.WebView2.Wpf.dll") "lib"
    Copy-Item (Join-Path $nugetFile "\runtimes\win-x64\native\WebView2Loader.dll") "lib"

    Write-Host "不要になったnugetパッケージ類を削除します。"
    Remove-Item $nugetFile -Recurse
    Remove-Item $nugetZipFile

    if ((Test-Path $libWebView2Wpf) -and (Test-Path $libWebView2Core) -and (Test-Path $libWebview2Loader)) {
        Read-Host "取得に成功しました。boot.bat で PS-Edge の起動をご確認ください[Enter]"
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

$webview  = $window.findName("webView")
$goButton = $window.findName("pageChange")
$urlText  = $window.findName("pageURL")

<# WebView2 の設定 #>
$webview.CreationProperties = New-Object 'Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties'
$webview.CreationProperties.UserDataFolder = (Join-Path $PSScriptRoot "data")
$webview.Source = "file:///" + (Join-Path $PSScriptRoot "page01.html")

<# Set EventListener #>
$goButton.add_Click({
    $webview.Source = $urlText.Text
})

$webview.add_SourceChanged({
    $urlText.Text = $webview.Source
})

$window.add_LocationChanged({
    param($event)
    $webview.CoreWebView2.PostWebMessageAsJson((@{xPos=$event.Left; yPos=$event.Top} | ConvertTo-Json))  # JSON データ用サンプル行
})

<# WebView2 Messaging #>
$webview.add_WebMessageReceived({
    param($webview, $message)
    $json = ($message.WebMessageAsJson | ConvertFrom-Json)
    $window.Title = $json.PageTitle
})

<# Window の表示 #>
[void]$window.ShowDialog()
$window.Close()
