# Собирает catalog.html и скачивает изображения в ../images/catalog/
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outHtml = Join-Path $root "catalog.html"
$imgDir = Join-Path $root "images\catalog"
$urlList = Join-Path $root "_urls_all.txt"
$base = "https://slt-aqua.ru"

New-Item -ItemType Directory -Force -Path $imgDir | Out-Null

$skipAggregatorUrls = @(
  '/catalog/slt-blockfire/',
  '/catalog/slt-aqua/',
  '/catalog/slt-aquasept/',
  '/catalog/slt-aquasept-lns/',
  '/catalog/slt-pe-rt/',
  '/catalog/instrumenty/'
)
$urls = Get-Content $urlList | Where-Object { $_ -match '\S' -and ($skipAggregatorUrls -notcontains $_) }
$productRx = [regex]::new(
  '(?s)<a class="card" href="([^"]+)"[^>]*itemprop="url"[^>]*>.*?<img src="([^"]+)" alt="" itemprop="image"[^>]*>.*?<div class="card__title" itemprop="name"[^>]*>([^<]+)</div>',
  [System.Text.RegularExpressions.RegexOptions]::Compiled
)
$h1Rx = [regex]::new('<h1 class="custom-h1[^"]*"[^>]*>\s*([^<]+)', [System.Text.RegularExpressions.RegexOptions]::Compiled)

$imgMap = @{}  # absolute url -> relative local path

function Get-LocalImagePath {
  param([string]$src)
  if ($src.StartsWith("//")) { $src = "https:" + $src }
  elseif ($src.StartsWith("/")) { $src = $base + $src }
  if ($imgMap.ContainsKey($src)) { return $imgMap[$src] }
  $uri = [Uri]$src
  $leaf = Split-Path $uri.AbsolutePath -Leaf
  if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = "img.bin" }
  $safe = [regex]::Replace($leaf, '[^a-zA-Z0-9._\-]', "_")
  $destName = $safe
  $n = 1
  while (Test-Path (Join-Path $imgDir $destName)) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($safe)
    $ext = [IO.Path]::GetExtension($safe)
    $destName = "${stem}_${n}${ext}"
    $n++
  }
  $dest = Join-Path $imgDir $destName
  try {
    Invoke-WebRequest -Uri $src -OutFile $dest -UseBasicParsing
  } catch {
    Write-Warning "IMG FAIL $src :: $_"
    return ""
  }
  $rel = "images/catalog/$destName"
  $imgMap[$src] = $rel
  return $rel
}

$sections = New-Object System.Collections.Generic.List[object]

foreach ($path in $urls) {
  $pageUrl = $base + $path
  try {
    $html = (Invoke-WebRequest -Uri $pageUrl -UseBasicParsing).Content
  } catch {
    Write-Warning "PAGE FAIL $pageUrl"
    continue
  }
  $h1m = $h1Rx.Match($html)
  $sectionTitle = if ($h1m.Success) { $h1m.Groups[1].Value.Trim() } else { $path.Trim('/').Replace('/', ' · ') }
  $slug = ($path.Trim('/') -replace '[^a-zA-Z0-9]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "root" }

  $products = @()
  foreach ($m in $productRx.Matches($html)) {
    $imgSrc = $m.Groups[2].Value
    if ($imgSrc.StartsWith("/")) { $imgAbs = $base + $imgSrc } else { $imgAbs = $imgSrc }
    $local = ""
    if ($imgMap.ContainsKey($imgAbs)) {
      $local = $imgMap[$imgAbs]
    } else {
      $local = Get-LocalImagePath -src $imgAbs
    }
    $products += [ordered]@{
      name = $m.Groups[3].Value.Trim()
      img  = $local
      href = $m.Groups[1].Value
    }
  }
  if ($products.Count -eq 0) { continue }

  $sections.Add([ordered]@{
      slug  = $slug
      path  = $path
      title = $sectionTitle
      items = $products
    }) | Out-Null
}

function HtmlEscape([string]$t) {
  if ($null -eq $t) { return "" }
  return [System.Net.WebUtility]::HtmlEncode($t)
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<!DOCTYPE html>')
[void]$sb.AppendLine('<html lang="ru">')
[void]$sb.AppendLine('<head>')
[void]$sb.AppendLine('  <meta charset="UTF-8" />')
[void]$sb.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />')
[void]$sb.AppendLine('  <meta name="theme-color" content="#060b14" />')
[void]$sb.AppendLine('  <title>Каталог | SLT-Узел Тольятти — трубы и фитинги СЛТ Аква</title>')
[void]$sb.AppendLine('  <meta name="description" content="Полный каталог SLT BLOCKFIRE, AQUA, AQUASEPT и других линеек завода СЛТ Аква. SLT-Узел Тольятти — прайс и поставка." />')
[void]$sb.AppendLine('  <link rel="icon" href="favicon.svg" type="image/svg+xml" sizes="any" />')
[void]$sb.AppendLine('  <link rel="apple-touch-icon" href="favicon.svg" />')
[void]$sb.AppendLine('  <link rel="manifest" href="site.webmanifest" />')
[void]$sb.AppendLine('  <link rel="canonical" href="https://slt-uzel-tlt.netlify.app/catalog.html" />')
[void]$sb.AppendLine('  <meta property="og:type" content="website" />')
[void]$sb.AppendLine('  <meta property="og:url" content="https://slt-uzel-tlt.netlify.app/catalog.html" />')
[void]$sb.AppendLine('  <meta property="og:site_name" content="SLT-Узел Тольятти" />')
[void]$sb.AppendLine('  <meta property="og:title" content="Каталог СЛТ Аква | SLT-Узел Тольятти" />')
[void]$sb.AppendLine('  <meta property="og:description" content="Трубы, фитинги и арматура завода СЛТ Аква — все линейки на одном сайте." />')
[void]$sb.AppendLine('  <link rel="stylesheet" href="styles.css" />')
[void]$sb.AppendLine('</head>')
[void]$sb.AppendLine('<body>')
[void]$sb.AppendLine('<a class="skip-link" href="#catalog-main">К каталогу</a>')
$topId = 'top'
[void]$sb.AppendLine("<div id=`"$topId`" class=`"anchor-page-top`" tabindex=`"-1`" aria-hidden=`"true`"></div>")
[void]$sb.AppendLine('<div class="site-head">')
[void]$sb.AppendLine('  <div class="container site-head__shell">')
[void]$sb.AppendLine('    <div class="site-head__bar">')
[void]$sb.AppendLine('      <div class="site-head__bg" aria-hidden="true"></div>')
[void]$sb.AppendLine('      <a class="logo" href="index.html" aria-label="SLT-Узел Тольятти — на главную">')
[void]$sb.AppendLine('        <span class="logo-icon" aria-hidden="true">')
[void]$sb.AppendLine('          <svg class="logo-svg" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">')
[void]$sb.AppendLine('            <defs>')
[void]$sb.AppendLine('              <linearGradient id="logo-grad-pipe-cat" x1="10" y1="10" x2="38" y2="38" gradientUnits="userSpaceOnUse">')
[void]$sb.AppendLine('                <stop stop-color="#ff7a35" /><stop offset="1" stop-color="#22d3ee" />')
[void]$sb.AppendLine('              </linearGradient>')
[void]$sb.AppendLine('              <linearGradient id="logo-grad-shine-cat" x1="24" y1="14" x2="24" y2="34" gradientUnits="userSpaceOnUse">')
[void]$sb.AppendLine('                <stop stop-color="#ffffff" stop-opacity="0.22" /><stop offset="1" stop-color="#ffffff" stop-opacity="0" />')
[void]$sb.AppendLine('              </linearGradient>')
[void]$sb.AppendLine('            </defs>')
[void]$sb.AppendLine('            <rect x="3" y="3" width="42" height="42" rx="13" fill="#15243d" stroke="url(#logo-grad-pipe-cat)" stroke-width="1.5" />')
[void]$sb.AppendLine('            <path d="M11 23.5h26M24 23.5v15.5" stroke="url(#logo-grad-pipe-cat)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" />')
[void]$sb.AppendLine('            <path d="M11 22.5h26M24 22.5v15.5" stroke="url(#logo-grad-shine-cat)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />')
[void]$sb.AppendLine('            <circle cx="24" cy="23.5" r="8" fill="#0b1424" stroke="url(#logo-grad-pipe-cat)" stroke-width="2" />')
[void]$sb.AppendLine('            <circle cx="24" cy="23.5" r="3.2" fill="#ff5c1a" />')
[void]$sb.AppendLine('          </svg>')
[void]$sb.AppendLine('        </span>')
[void]$sb.AppendLine('        <span class="logo-text-stack">')
[void]$sb.AppendLine('          <span class="logo-text-line1">SLT-<strong>Узел</strong></span>')
[void]$sb.AppendLine('          <span class="logo-text-line2">каталог</span>')
[void]$sb.AppendLine('        </span>')
[void]$sb.AppendLine('      </a>')
[void]$sb.AppendLine('      <button type="button" class="nav-toggle" aria-expanded="false" aria-controls="cat-nav" aria-label="Меню">')
[void]$sb.AppendLine('        <span></span><span></span><span></span>')
[void]$sb.AppendLine('      </button>')
[void]$sb.AppendLine('      <div class="header-contact">')
[void]$sb.AppendLine('        <a class="tel" href="tel:+79278972233">+7 927 897-22-33</a>')
[void]$sb.AppendLine('        <a class="btn btn-sm btn-ghost" href="https://wa.me/79278972233" target="_blank" rel="noopener noreferrer">WhatsApp</a>')
[void]$sb.AppendLine('      </div>')
[void]$sb.AppendLine('    </div>')
[void]$sb.AppendLine('    <nav class="site-nav" id="cat-nav" aria-label="Каталог">')
[void]$sb.AppendLine('      <a href="index.html#lead">Заявка / прайс</a>')
[void]$sb.AppendLine('      <a href="index.html#contacts">Контакты</a>')
[void]$sb.AppendLine('      <a href="#cat-blockfire">SLT BLOCKFIRE</a>')
[void]$sb.AppendLine('      <a href="#cat-slt-aqua">SLT AQUA</a>')
[void]$sb.AppendLine('      <a href="#cat-slt-aquasept">AQUASEPT</a>')
[void]$sb.AppendLine('      <a href="#cat-slt-pe-rt">PE-RT</a>')
[void]$sb.AppendLine('      <a href="#cat-instrumenty">Инструменты</a>')
[void]$sb.AppendLine('    </nav>')
[void]$sb.AppendLine('  </div>')
[void]$sb.AppendLine('</div>')

[void]$sb.AppendLine('<main id="catalog-main" class="catalog-page-wrap">')
[void]$sb.AppendLine('  <section class="section section-tight catalog-hero">')
[void]$sb.AppendLine('    <div class="container">')
[void]$sb.AppendLine('      <h1 class="catalog-page-title">Каталог продукции завода СЛТ Аква</h1>')
[void]$sb.AppendLine('      <p class="muted catalog-page-lead">Все разделы и позиции собраны здесь. Уточнить наличие, диаметры и цену — <a href="index.html#lead">оставьте заявку</a> или <a href="index.html#contacts">позвоните</a>.</p>')
[void]$sb.AppendLine('    </div>')
[void]$sb.AppendLine('  </section>')

$groupOrder = @(
  @{ key = "slt-blockfire"; label = "SLT BLOCKFIRE — пожаротушение, ВПВ"; id = "cat-blockfire" },
  @{ key = "slt-aqua";      label = "SLT AQUA — водоснабжение и отопление"; id = "cat-slt-aqua" },
  @{ key = "slt-aquasept";  label = "SLT AQUASEPT и LNS — канализация"; id = "cat-slt-aquasept" },
  @{ key = "slt-pe-rt";     label = "SLT PE-RT — гибкие трубы"; id = "cat-slt-pe-rt" },
  @{ key = "instrumenty";   label = "Инструменты для монтажа"; id = "cat-instrumenty" }
)

foreach ($g in $groupOrder) {
  $key = $g.key
  $subs = switch ($key) {
    "slt-aqua" {
      $sections | Where-Object {
        $_.path -match '^/catalog/slt-aqua/' -and $_.path -notmatch '^/catalog/slt-aquasept'
      }
    }
    "slt-aquasept" {
      $sections | Where-Object { $_.path -match '^/catalog/slt-aquasept' }
    }
    default {
      $esc = [regex]::Escape($key)
      $sections | Where-Object { $_.path -match "^/catalog/$esc/" }
    }
  }
  if (-not $subs -or $subs.Count -eq 0) { continue }
  [void]$sb.AppendLine("  <div class=`"catalog-group`" id=`"$($g.id)`">")
  [void]$sb.AppendLine('    <div class="container">')
  [void]$sb.AppendLine("      <h2 class=`"catalog-group-title`">$($g.label)</h2>")
  foreach ($sec in $subs) {
    [void]$sb.AppendLine("      <section class=`"catalog-section`" id=`"$($sec.slug)`" aria-labelledby=`"title-$($sec.slug)`">")
    [void]$sb.AppendLine("        <h3 class=`"catalog-section-title`" id=`"title-$($sec.slug)`">$(HtmlEscape $sec.title)</h3>")
    [void]$sb.AppendLine('        <div class="catalog-grid" role="list">')
    foreach ($p in $sec.items) {
      $nm = HtmlEscape $p.name
      $im = HtmlEscape $p.img
      [void]$sb.AppendLine('          <article class="catalog-item" role="listitem">')
      if ($im) {
        [void]$sb.AppendLine("            <div class=`"catalog-item-media`"><img src=`"$im`" alt=`"$nm`" width=`"313`" height=`"313`" loading=`"lazy`" decoding=`"async`" /></div>")
      }
      [void]$sb.AppendLine('            <div class="catalog-item-body">')
      [void]$sb.AppendLine("              <div class=`"catalog-item-name`">$nm</div>")
      [void]$sb.AppendLine('              <a class="btn btn-sm btn-primary catalog-item-cta" href="index.html#lead">Запросить</a>')
      [void]$sb.AppendLine('            </div>')
      [void]$sb.AppendLine('          </article>')
    }
    [void]$sb.AppendLine('        </div>')
    [void]$sb.AppendLine('      </section>')
  }
  [void]$sb.AppendLine('    </div>')
  [void]$sb.AppendLine('  </div>')
}

[void]$sb.AppendLine('</main>')
[void]$sb.AppendLine('<footer class="site-footer">')
[void]$sb.AppendLine('  <div class="container footer-inner">')
[void]$sb.AppendLine('    <p><strong>SLT-Узел Тольятти</strong> — каталог по данным производителя. Поставки — ИП Барабанщиков Анатолий Александрович.</p>')
[void]$sb.AppendLine('    <div class="footer-links"><a href="index.html">Главная</a><a class="footer-up" href="#top">Наверх</a></div>')
[void]$sb.AppendLine('  </div>')
[void]$sb.AppendLine('</footer>')
[void]$sb.AppendLine('<button type="button" class="scroll-top-fab" aria-label="Наверх страницы" aria-hidden="true" tabindex="-1">')
[void]$sb.AppendLine('  <svg class="scroll-top-fab__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">')
[void]$sb.AppendLine('    <path d="M18 15l-6-6-6 6" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" />')
[void]$sb.AppendLine('  </svg>')
[void]$sb.AppendLine('</button>')
[void]$sb.AppendLine('<script src="app.js" defer></script>')
[void]$sb.AppendLine('</body></html>')

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outHtml, $sb.ToString(), $utf8NoBom)
Write-Host "Wrote $outHtml sections=$($sections.Count) images=$($imgMap.Count)"
