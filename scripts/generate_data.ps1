# HERMES - generator syntetycznych danych sprzedazowych (v2 - katalog 64 SKU / 8 kategorii)
# Model popytu: Q = Q0 * (P/P0)^E * (Pc/Pc0)^crossE * sezonowosc * trend * szum_lognormalny
# Elastycznosc (E) jest "wszyta" celowo per produkt - w Kroku 6 walidujemy, ze model DAX ja odzyskuje.
#
# Katalog zawiera model "razor-and-blades": Drukarki (cienka marza, elastyczne, E ~ -1.6..-2.2)
# vs Tusze/Tonery (gruba marza, nieelastyczne, E ~ -0.2..-0.6) - lock-in konsumenta po zakupie drukarki.

Get-Random -SetSeed 42 | Out-Null

# WAZNE: wymuszamy kropke jako separator dziesietny (bez tego polska lokalizacja
# zapisuje "392,77" z przecinkiem i rozwala kolumny CSV).
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$outDir = "C:\Users\micha\Desktop\hermes\data"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

function Get-Normal {
    $u1 = Get-Random -Minimum 0.0000001 -Maximum 1.0
    $u2 = Get-Random -Minimum 0.0000001 -Maximum 1.0
    return [math]::Sqrt(-2.0 * [math]::Log($u1)) * [math]::Cos(2.0 * [math]::PI * $u2)
}

function Get-RandomDouble {
    param([double]$Min, [double]$Max)
    return $Min + (Get-Random -Minimum 0.0 -Maximum 1.0) * ($Max - $Min)
}

# --- Definicje kategorii: zakresy cen, elastycznosci, cross-elastycznosci, wolumenu bazowego, kosztu (jako % ceny) ---
# CostFrac = koszt jako ulamek ceny -> nizszy CostFrac = grubsza marza (klasyczny model "blades")
$categories = @(
    @{ Name="Printers";                  Items=@("LaserJet Compact 210","InkFlow Home 150","OfficeJet Pro 400","PhotoPrint Studio X","LaserJet Business 800");
       PriceMin=150; PriceMax=650;  ElastMin=-2.2; ElastMax=-1.6; CrossMin=0.15; CrossMax=0.30; Q0Min=6;  Q0Max=18;  CostFracMin=0.72; CostFracMax=0.88 },

    @{ Name="Ink & Toner";               Items=@("Ink Cartridge - Black XL","Ink Cartridge - Color Pack","Toner Cartridge - Standard","Toner Cartridge - High Yield","Photo Ink Cartridge Set","Ink Cartridge - Black Standard","Ink Cartridge - Cyan","Ink Cartridge - Magenta","Ink Cartridge - Yellow","Toner Cartridge - Business Pack");
       PriceMin=18;  PriceMax=75;   ElastMin=-0.6; ElastMax=-0.2; CrossMin=0.05; CrossMax=0.15; Q0Min=20; Q0Max=70;  CostFracMin=0.12; CostFracMax=0.28 },

    @{ Name="Laptops";                   Items=@("UltraBook Air 13","ProBook 15 Business","Gaming Laptop RTX Series","ConvertiBook 2-in-1","UltraBook Pro 14");
       PriceMin=1400;PriceMax=6000; ElastMin=-2.0; ElastMax=-1.3; CrossMin=0.20; CrossMax=0.40; Q0Min=3;  Q0Max=10;  CostFracMin=0.68; CostFracMax=0.82 },

    @{ Name="Laptop Accessories";        Items=@("Laptop Backpack Pro","Laptop Sleeve 14-inch","USB-C Docking Station","Laptop Stand Aluminum","Cooling Pad","Universal Laptop Charger 65W","Laptop Privacy Screen","External SSD Enclosure");
       PriceMin=35;  PriceMax=260;  ElastMin=-1.6; ElastMax=-0.9; CrossMin=0.15; CrossMax=0.35; Q0Min=15; Q0Max=45;  CostFracMin=0.35; CostFracMax=0.55 },

    @{ Name="Peripherals";               Items=@("Wireless Mouse","Wireless Keyboard","Mechanical Keyboard RGB","Ergonomic Vertical Mouse","27-inch Monitor FHD","27-inch Monitor 4K","Webcam HD 1080p","Webcam 4K Pro","Graphics Tablet","Trackball Mouse");
       PriceMin=50;  PriceMax=950;  ElastMin=-1.8; ElastMax=-1.0; CrossMin=0.20; CrossMax=0.40; Q0Min=10; Q0Max=50;  CostFracMin=0.35; CostFracMax=0.55 },

    @{ Name="Cables & Connectivity";     Items=@("USB-C Cable 1m","USB-C Cable 2m","HDMI Cable 2m","USB-C to HDMI Adapter","USB Hub 7-Port","DisplayPort Cable","Ethernet Cable Cat6","Multi-Port Travel Adapter");
       PriceMin=12;  PriceMax=65;   ElastMin=-2.6; ElastMax=-1.8; CrossMin=0.35; CrossMax=0.55; Q0Min=40; Q0Max=140; CostFracMin=0.25; CostFracMax=0.40 },

    @{ Name="Audio";                     Items=@("Bluetooth Headphones Over-Ear","Wireless Earbuds","Noise Cancelling Headphones","Portable Bluetooth Speaker","Soundbar Compact","Wired Earphones","Gaming Headset","Studio Monitor Headphones");
       PriceMin=70;  PriceMax=650;  ElastMin=-2.0; ElastMax=-1.2; CrossMin=0.25; CrossMax=0.45; Q0Min=12; Q0Max=45;  CostFracMin=0.38; CostFracMax=0.58 },

    @{ Name="Mobile Cases & Protection"; Items=@("Phone Case - Silicone","Phone Case - Rugged","Screen Protector - Tempered Glass","Screen Protector - Privacy","Car Phone Mount");
       PriceMin=15;  PriceMax=60;   ElastMin=-0.8; ElastMax=-0.3; CrossMin=0.10; CrossMax=0.25; Q0Min=50; Q0Max=160; CostFracMin=0.15; CostFracMax=0.30 },

    @{ Name="Mobile Charging";           Items=@("Power Bank 10000mAh","Power Bank 20000mAh","Wireless Charger Pad","USB Wall Charger 20W","MagSafe Charger Compatible");
       PriceMin=35;  PriceMax=180;  ElastMin=-1.5; ElastMax=-0.9; CrossMin=0.20; CrossMax=0.40; Q0Min=20; Q0Max=60;  CostFracMin=0.35; CostFracMax=0.55 }
)

# --- Budowa katalogu 64 produktow ---
$products = New-Object System.Collections.Generic.List[hashtable]
$nextId = 1
foreach ($cat in $categories) {
    foreach ($itemName in $cat.Items) {
        $p0 = [math]::Round((Get-RandomDouble -Min $cat.PriceMin -Max $cat.PriceMax), 2)
        $q0 = Get-Random -Minimum $cat.Q0Min -Maximum ($cat.Q0Max + 1)
        $e  = [math]::Round((Get-RandomDouble -Min $cat.ElastMin -Max $cat.ElastMax), 2)
        $cross = [math]::Round((Get-RandomDouble -Min $cat.CrossMin -Max $cat.CrossMax), 2)
        $costFrac = Get-RandomDouble -Min $cat.CostFracMin -Max $cat.CostFracMax
        $cost = [math]::Round($p0 * $costFrac, 2)

        $products.Add(@{
            Id = $nextId; Name = $itemName; Cat = $cat.Name
            P0 = $p0; Q0 = $q0; E = $e; Cost = $cost; Cross = $cross
        })
        $nextId++
    }
}

$startDate = [datetime]"2024-01-01"
$endDate   = [datetime]"2025-12-31"

# Mnozniki sezonowe wg miesiaca (Q4 gorka, styczen dolek)
$monthFactor = @{ 1=0.90; 2=0.93; 3=0.99; 4=1.00; 5=1.02; 6=1.00; 7=0.97; 8=0.99; 9=1.04; 10=1.08; 11=1.20; 12=1.24 }

$factRows = New-Object System.Collections.Generic.List[string]
$factRows.Add("Date,ProductID,UnitPrice,CompetitorPrice,PromoFlag,Quantity")

foreach ($p in $products) {
    $step1Day = Get-Random -Minimum 180 -Maximum 300
    $step2Day = Get-Random -Minimum 420 -Maximum 600
    $step1 = 1 + ((Get-Random -Minimum -8 -Maximum 8) / 100.0)
    $step2 = 1 + ((Get-Random -Minimum -8 -Maximum 8) / 100.0)

    $compBase = [math]::Round($p.P0 * (1 + ((Get-Random -Minimum -5 -Maximum 5)/100.0)), 2)

    $promoDaysLeft = 0
    $promoDepth = 0.0
    $compPromoLeft = 0

    $dayIndex = 0
    $d = $startDate
    while ($d -le $endDate) {
        $price = $p.P0
        if ($dayIndex -ge $step1Day) { $price = $price * $step1 }
        if ($dayIndex -ge $step2Day) { $price = $price * $step2 }

        if ($promoDaysLeft -le 0 -and (Get-Random -Minimum 0.0 -Maximum 1.0) -lt 0.045) {
            $promoDaysLeft = Get-Random -Minimum 4 -Maximum 9
            $promoDepth = (Get-Random -Minimum 15 -Maximum 32) / 100.0
        }
        $promoFlag = 0
        if ($promoDaysLeft -gt 0) {
            $price = $price * (1 - $promoDepth)
            $promoFlag = 1
            $promoDaysLeft--
        }
        $price = [math]::Round($price, 2)

        $compPrice = $compBase * (1 + ($step1-1)*0.5)
        if ($compPromoLeft -le 0 -and (Get-Random -Minimum 0.0 -Maximum 1.0) -lt 0.030) {
            $compPromoLeft = Get-Random -Minimum 3 -Maximum 7
        }
        if ($compPromoLeft -gt 0) {
            $compPrice = $compPrice * (1 - ((Get-Random -Minimum 12 -Maximum 25)/100.0))
            $compPromoLeft--
        }
        $compPrice = $compPrice * (1 + (Get-Normal)*0.02)
        $compPrice = [math]::Round($compPrice, 2)

        $weekFactor = 1.0
        if ($d.DayOfWeek -eq 'Saturday' -or $d.DayOfWeek -eq 'Sunday') { $weekFactor = 1.15 }
        elseif ($d.DayOfWeek -eq 'Monday') { $weekFactor = 0.92 }

        $trend = 1 + 0.0003 * $dayIndex
        $mf = $monthFactor[$d.Month]

        $priceRatio = $price / $p.P0
        $compRatio  = $compPrice / $compBase

        $mean = $p.Q0 * [math]::Pow($priceRatio, $p.E) * [math]::Pow($compRatio, $p.Cross) * $weekFactor * $mf * $trend
        $qty  = [math]::Round($mean * [math]::Exp((Get-Normal) * 0.11))
        if ($qty -lt 0) { $qty = 0 }

        $factRows.Add(("{0},{1},{2},{3},{4},{5}" -f $d.ToString("yyyy-MM-dd"), $p.Id, $price, $compPrice, $promoFlag, [int]$qty))

        $dayIndex++
        $d = $d.AddDays(1)
    }
}

$factRows -join "`n" | Out-File -FilePath "$outDir\fact_sales.csv" -Encoding utf8

$dimRows = New-Object System.Collections.Generic.List[string]
$dimRows.Add("ProductID,ProductName,Category,UnitCost,BasePrice")
foreach ($p in $products) {
    $dimRows.Add(("{0},{1},{2},{3},{4}" -f $p.Id, $p.Name, $p.Cat, $p.Cost, $p.P0))
}
$dimRows -join "`n" | Out-File -FilePath "$outDir\dim_product.csv" -Encoding utf8

$keyRows = New-Object System.Collections.Generic.List[string]
$keyRows.Add("ProductID,ProductName,Category,TrueElasticity")
foreach ($p in $products) {
    $keyRows.Add(("{0},{1},{2},{3}" -f $p.Id, $p.Name, $p.Cat, $p.E))
}
$keyRows -join "`n" | Out-File -FilePath "$outDir\_answer_key_elasticity.csv" -Encoding utf8

Write-Host ("Wygenerowano wierszy fact_sales: " + ($factRows.Count - 1))
Write-Host ("Produktow: " + $products.Count)
Write-Host ("Kategorii: " + $categories.Count)
Write-Host ("Pliki w: " + $outDir)
