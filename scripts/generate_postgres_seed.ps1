# HERMES - generuje seed SQL dla "zywej" ceny konkurencji (do warstwy DirectQuery, Krok 8).
# Startuje od BasePrice produktu i lekko "jittruje" (+/- 12%), zeby live cena
# realnie roznila sie od historycznego CompetitorPrice w fact_sales - inaczej
# demo DirectQuery vs Import wygladaloby identycznie i nic by nie pokazywalo.

Get-Random -SetSeed 99 | Out-Null
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$products = Import-Csv "C:\Users\micha\Desktop\hermes\data\dim_product.csv"

$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("-- HERMES: seed dla live_competitor_prices (Krok 8 - Composite Model / DirectQuery)")
$rows.Add("CREATE TABLE IF NOT EXISTS live_competitor_prices (")
$rows.Add("    product_id INT PRIMARY KEY,")
$rows.Add("    product_name TEXT NOT NULL,")
$rows.Add("    competitor_price NUMERIC(10,2) NOT NULL,")
$rows.Add("    last_updated TIMESTAMP NOT NULL DEFAULT NOW()")
$rows.Add(");")
$rows.Add("")
$rows.Add("TRUNCATE TABLE live_competitor_prices;")
$rows.Add("")
$rows.Add("INSERT INTO live_competitor_prices (product_id, product_name, competitor_price) VALUES")

$valueLines = New-Object System.Collections.Generic.List[string]
foreach ($p in $products) {
    $base = [double]$p.BasePrice
    $jitter = 1 + ((Get-Random -Minimum -12 -Maximum 12) / 100.0)
    $livePrice = [math]::Round($base * $jitter, 2)
    $safeName = $p.ProductName.Replace("'", "''")
    $valueLines.Add("    ($($p.ProductID), '$safeName', $livePrice)")
}
$rows.Add(($valueLines -join ",`n") + ";")

$rows -join "`n" | Out-File -FilePath "C:\Users\micha\Desktop\hermes\scripts\seed_postgres.sql" -Encoding utf8

Write-Host "Zapisano: scripts\seed_postgres.sql ($($products.Count) produktow)"
