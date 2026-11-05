# Prompt for Claude Code: test setup on your own FiveM server

Paste the block below into Claude Code running on the machine that hosts the FiveM server.

```
Nastav mi anticheat jcks_anticheat na môj FiveM server v TESTOVACOM režime: má všetko detegovať a zapisovať, ale nikoho nekickovať, nebanovať ani mu nič nevracať. Budem ho testovať na vlastnom serveri.

Zdroj: GitHub repo jcksdevelopment/idk, branch "anticheat".
1. Získaj hotový resource:
   - buď stiahni artifact "jcks_anticheat-resource" z posledného úspešného GitHub Actions behu workflow "build" pre branch anticheat (gh run list --branch anticheat --workflow build; gh run download <id> --name jcks_anticheat-resource),
   - alebo naklonuj branch a zbuildi ho: ./scripts/package.sh (Linux, treba .NET SDK 10, lua5.4, zip) alebo powershell -ExecutionPolicy Bypass -File scripts\package.ps1 (Windows). Výsledok je dist/jcks_anticheat.
   Build bez licenčného kľúča je "dev build" a licenciu nekontroluje, to je pre test v poriadku.
2. Zisti, kde je server.cfg a priečinok resources. Skopíruj jcks_anticheat do resources/[jcks]/jcks_anticheat.
3. server.cfg (najprv sprav zálohu server.cfg):
   - musí byť "set onesync on",
   - pridaj "ensure jcks_anticheat" až za framework a ostatné resourcy,
   - pridaj "add_ace group.admin jcks_anticheat.admin allow" a priraď môj admin účet do group.admin, aby som mohol používať /jac,
   - NEPRIDÁVAJ "jcks_anticheat.bypass" účtu, ktorým budem testovať; s bypass by sa detekcie len označili ako bypass.
4. V resources/[jcks]/jcks_anticheat/config.json nastav (nič iné nemeň):
   - "dryRun": true
   - "countermeasures": { "enabled": true, "applyInDryRun": false, ... ostatné nechaj }
   - "detectionLog": { "enabled": true, "keepDays": 30 }
   - "integrations": "learning": true (ostatné nechaj)
   - "staffAlerts": { "enabled": true, "minAction": "log", "cooldownSeconds": 10 }
   - "vpnCheck": "enabled": false
   - "vision": "enabled": false
   Over, že je to platný JSON.
5. Spusti server. V serverovej konzole spusti: "jac shield install", potom "refresh", potom server reštartuj.
6. Po štarte spusti v konzole "jac doctor" a "jac audit". Ukáž mi výstup a vysvetli FAIL/WARN. Nastavenia server.cfg z auditu zatiaľ NEMEŇ, len mi ich vypíš (môžu rozbiť scripty).
7. Vytvor súbor jac-test/TESTLOG.md s tabuľkou: čas (HH:MM:SS) | fáza | čo som robil | čo som čakal. Budem ti diktovať, čo testujem, a ty to zapisuj s presným časom.
8. Keď poviem "zbieraj", zabaľ do jac-test/jac-test-<dátum>.zip:
   - resources/[jcks]/jcks_anticheat/data/detections/*.jsonl
   - posledný log servera (txAdmin alebo konzola),
   - výstup "jac doctor", "jac integrations suggest" a "jac status",
   - jac-test/TESTLOG.md,
   - config.json, ktorý bežal.
   Nič z toho neposielaj nikam von, len mi povedz, kde zip je.

Pravidlá: nemeň kód anticheatu ani iných resourcov, nevypínaj detekcie, nepomáhaj s ovládaním cheatu. Ak niečo zlyhá, ukáž mi chybu a navrhni opravu predtým, ako niečo zmeníš.
```

## Test plan

1. **Clean play, 20–30 min, without any cheat.** Walk, sprint, drive fast, swim, use a boat, parachute, die and respawn, use the hospital, garage, shop, job scripts and admin menu. Everything detected here is a false positive.
2. **The cheat, one feature at a time.** Turn on a single feature, use it for about 30 s, turn it off, wait 30 s, then go on to the next. Tell Claude each feature so it lands in TESTLOG.md with the time.
3. **Countermeasures.** Set `countermeasures.applyInDryRun` to `true` (`/jac panel`, or the file followed by `jac reload`) and repeat phase 2. You'll see what the anticheat undoes on its own.
4. **Collect the data** ("zbieraj") and send the zip.

Test only on your own server. Using a cheat client can get the account banned by FiveM itself, so use an account you don't mind losing.
