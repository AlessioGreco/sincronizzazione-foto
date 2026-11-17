# i18n.ps1 - translations. Strings live in lang\<code>.json (flat key -> text).
# Add a language: copy lang\en.json to lang\<code>.json, translate it, and add the code below.

$script:Strings = @{}
$script:Lang    = "en"

function Get-SupportedLanguages { @("en", "it") }

function Resolve-Language($setting) {
    if ($setting -and $setting -ne "auto" -and ((Get-SupportedLanguages) -contains $setting)) { return $setting }
    try {
        $two = (Get-UICulture).TwoLetterISOLanguageName
        if ((Get-SupportedLanguages) -contains $two) { return $two }
    } catch {}
    return "en"
}

function Read-LangFile($code) {
    $h = @{}
    $p = Join-Path $script:AppRoot "lang\$code.json"
    if (Test-Path -LiteralPath $p) {
        $j = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $j.PSObject.Properties) { $h[$prop.Name] = [string]$prop.Value }
    }
    return $h
}

function Set-Language($setting) {
    $code = Resolve-Language $setting
    $en   = Read-LangFile "en"
    $cur  = if ($code -eq "en") { $en } else { Read-LangFile $code }
    foreach ($k in $en.Keys) { if (-not $cur.ContainsKey($k)) { $cur[$k] = $en[$k] } }   # missing keys fall back to English
    $script:Strings = $cur
    $script:Lang    = $code
}

# T 'key' [args...]  ->  translated text, formatted with -f when arguments are given
function T([string]$key) {
    $s = $script:Strings[$key]
    if ($null -eq $s) { return "[$key]" }
    if ($args.Count -gt 0) { return ($s -f $args) }
    return $s
}
