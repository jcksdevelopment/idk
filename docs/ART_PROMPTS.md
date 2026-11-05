# 🎨 ART_PROMPTS — prompty na obrázky pre Bazar & Item Flipping Simulator

Tento súbor obsahuje **hotové prompty na generovanie obrázkov** (pre AI nástroje typu
Midjourney, DALL·E / ChatGPT, Ideogram, Leonardo, Stable Diffusion, Firefly…) pre
každý obrázok, ktorý hra používa alebo ktorý potrebuješ na stránku hry.

* Prompty sú **po anglicky**, lebo obrázkové AI im rozumejú najlepšie. Vysvetlivky okolo sú po slovensky.
* Každý prompt je **samostatný** – stačí skopírovať celý blok kódu.
* Pri každom obrázku je: **veľkosť**, **pozadie**, **kam ho nahrať** a **kam vložiť ID** (`Config.luau`).
* Ak nejaký obrázok ešte nemáš, nechaj v configu `""` – hra zobrazí **emoji** (nič sa nepokazí).

> 💡 **Tip:** Generuj vždy 4 varianty a vyber tú, ktorá najlepšie sedí k ostatným.
> Keď máš prvých 5–6 ikon hotových, pridávaj do promptu „same style as the reference
> image“ a prilož ich ako referenciu (ak to tvoj nástroj podporuje). Takto bude celá
> sada vyzerať ako jedna rodina.

---

## Obsah

1. [Štýlový manuál (STYLE GUIDE)](#1-štýlový-manuál-style-guide)
2. [Ako nahrať obrázky do Robloxu a získať ID](#2-ako-nahrať-obrázky-do-robloxu-a-získať-id)
3. [Ikona hry (512×512)](#3-ikona-hry)
4. [Thumbnaily hry (1920×1080)](#4-thumbnaily-hry-1920×1080)
5. [Predmety (33 ks)](#5-predmety-configimagesitems)
6. [Zvieratká – pets (10 ks)](#6-zvieratká--pets-configimagespets)
7. [Krabice / bedne (5 ks)](#7-krabice--bedne-configimagescrates)
8. [Vajíčka (2 ks)](#8-vajíčka-configimageseggs)
9. [Obrázky kariet v obchode (5 ks)](#9-obrázky-kariet-v-hernom-obchode-configimagesshop)
10. [Ikony Game Passov a Developer Products (5 ks)](#10-ikony-game-passov-a-developer-products-512×512-kruh)
11. [Ikony odznakov – badges (19 ks)](#11-ikony-odznakov--badges-512×512-kruh)
12. [Logo na načítavaciu obrazovku](#12-logo-na-načítavaciu-obrazovku)
13. [Skupina (group): ikona a banner](#13-roblox-skupina-group-ikona-a-banner)
14. [Banner na sociálne siete](#14-banner-na-sociálne-siete)
15. [Kontrolný zoznam pred nahraním](#15-kontrolný-zoznam-pred-nahraním)

---

## 1. Štýlový manuál (STYLE GUIDE)

Všetky obrázky by mali vyzerať, akoby ich nakreslil **jeden** umelec. Drž sa týchto pravidiel:

| Pravidlo | Prečo |
|---|---|
| Jasné, veselé farby, mäkké svetlo, žiadna tma ani krv | Hra je pre deti |
| Kreslený 3D „Roblox-like“ vzhľad: zaoblené tvary, hrubšie obrysy alebo čisté plochy | Ladí s Roblox Studio grafikou |
| **Bez textu** v obrázku (ak nie je výslovne uvedené inak) | Text je v hre preložený (SK/EN); AI navyše text často pokazí |
| Ikony: **priehľadné pozadie** (PNG), objekt v strede, okolo ~10 % voľného miesta | Hra ich kladie na farebné karty |
| Kruhové ikony (badges, pasy, produkty): dôležité veci v **strednom kruhu** | Roblox ich oreže do kruhu |
| Žiadne skutočné osoby, žiadne známe postavičky (Disney, Pokémon, Minecraft…), žiadne logá značiek | Pravidlá Robloxu a autorské práva |
| Farby rarít: **Trash** = sivá/hnedá, **Rare** = modrá žiara, **Legendary** = zlatá žiara a iskričky | Rovnaké farby používa hra (`Items.RarityColors`) |

### Spoločný štýlový blok (už je vložený v každom prompte nižšie)

```text
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes,
clean smooth surfaces, soft studio lighting with gentle rim light, subtle soft shadow,
saturated cheerful colors, thick clean outlines, high detail but simple readable silhouette,
kid-safe, centered subject, no text, no watermark
```

### Spoločný negatívny prompt (ak nástroj má pole „Negative prompt“)

```text
text, letters, numbers, watermark, signature, logo, brand names, realistic photo, gore, blood,
scary, horror, creepy face, weapons, dark gloomy lighting, cluttered background, blurry,
low resolution, deformed, extra limbs, real person, celebrity, copyrighted character
```

> Midjourney: negatívny prompt dávaš ako `--no text, watermark, ...`.
> ChatGPT/DALL·E nemá pole na negatívny prompt – napíš na koniec vety „Avoid: …“.

### Veľkosti a formáty – ťahák

| Typ | Veľkosť | Pozadie | Formát |
|---|---|---|---|
| Ikona hry | 512×512 | plné (farebné) | PNG/JPG |
| Thumbnail | 1920×1080 (16:9), < 3 MB | plné | PNG/JPG |
| Predmet / pet / krabica / vajíčko / karta obchodu | 512×512 | **priehľadné** | PNG |
| Game Pass / Dev Product ikona | 512×512 (max), kruhový orez | plné, kruh v strede | PNG/JPG/BMP |
| Badge (odznak) | 512×512, kruhový orez | plné, kruh v strede | PNG/JPG |
| Logo (loading screen) | 1024×1024 | **priehľadné** | PNG |
| Ikona skupiny | 512×512 | plné | PNG |
| Banner sociálnych sietí | 1500×500 (X/Twitter), 2560×1440 (YouTube) | plné | PNG/JPG |

> Ak AI nevie vyrobiť priehľadné pozadie, vygeneruj objekt na **čisto bielom alebo
> zelenom pozadí** a pozadie odstráň (napr. Canva „Remove background“, remove.bg,
> Photopea → Magic Wand). Potom zmenši na 512×512.

---

## 2. Ako nahrať obrázky do Robloxu a získať ID

### 2.1 Herné obrázky (predmety, pets, krabice, vajíčka, karty obchodu, logo)

1. Otvor **Creator Hub** (create.roblox.com) → **Creations** → vyber svoju hru.
2. Nahrávať môžeš dvoma spôsobmi:
   * **V Roblox Studiu (odporúčané):** *Window → Asset Manager* → **Import** (alebo *Bulk Import*)
     → vyber PNG súbory. Potom na obrázok klikni pravým → **Copy Asset ID**.
   * **Na webe:** Creator Hub → **Development Items → Decals** → *Upload Asset*.
3. Každý nahraný obrázok prejde **moderovaním** (zvyčajne pár minút až pár hodín).
   Kým nie je schválený, hráči ho nevidia. Ak ho zamietnu, príde ti správa s dôvodom.
4. ID vlož do `src/shared/Config.luau` vo formáte **`"rbxassetid://<ID>"`**, napr.:

```lua
Config.Images = {
	Logo = "rbxassetid://1234567890",
	Items = {
		RustySpoon = "rbxassetid://1234567891",
		-- ...
	},
}
```

### 2.2 ⚠️ Pasca: Decal ID ≠ Image ID

Keď obrázok nahráš na webe ako **Decal**, Roblox vytvorí **dve** veci: *Decal*
(s jedným číslom v URL) a pod ním skutočný *Image* (s **iným** číslom). `ImageLabel`
v hre potrebuje **Image ID**. Keď vložíš Decal ID do kódu, obrázok sa **nezobrazí**
(ostane prázdny štvorček).

Ako získať správne Image ID:

* **Najjednoduchšie:** nahraj cez **Asset Manager v Studiu** a použi **Copy Asset ID** – to už je Image ID.
* **Ak máš Decal ID:** v Studiu vlož ľubovoľný `ImageLabel`, do vlastnosti **Image** vlož
  Decal ID a stlač Enter. Studio ho samo prevedie na `rbxassetid://<Image ID>` – to číslo skopíruj do configu.
* **Kontrola:** po vložení ID spusti *Play* – ak vidíš emoji namiesto obrázka, ID je zlé
  alebo obrázok ešte čaká na moderovanie.

### 2.3 Ikona hry a thumbnaily

Creator Hub → tvoja hra → **Configure / Places → Basic Settings** (sekcia *Icon* a *Thumbnails*).
Môžeš mať až **10 thumbnailov/videí**. Thumbnaily a ikona sa **nevkladajú do configu**.

### 2.4 Ikony Game Passov a Developer Products

Creator Hub → tvoja hra → **Monetization → Passes** (alebo **Developer Products**) → pri
vytváraní / úprave klikni **Upload Image**. Max 512×512, `.jpg/.png/.bmp`, dôležitý obsah
v kruhu. ID pasu/produktu (nie obrázka!) ide do `Config.GamePasses` / `Config.DevProducts`
(podrobne v [LAUNCH_PLAN.md](LAUNCH_PLAN.md#4-ceny-v-robuxoch-a-vytvorenie-pasov-a-produktov)).

### 2.5 Odznaky (badges)

Creator Hub → tvoja hra → **Engagement → Badges → Create a Badge** → *Upload Image*
(512×512, oreže sa do kruhu) → vyplň názov a popis → **Create**. Skopíruj **Badge ID**
(číslo) do `Config.Badges.<Id>` (číslo, nie text; `0` = vypnuté).
**Zadarmo môžeš vytvoriť 5 odznakov za 24 hodín (GMT) pre každú hru**, ďalší stojí 100 Robux.
Hra má 19 odznakov → rozlož to na 4 dni a nezaplatíš nič.

### 2.6 Pravidlá, ktoré musíš dodržať

* **Žiadne zavádzajúce thumbnaily/ikony.** Obrázky musia ukazovať to, čo v hre naozaj je.
  Nepíš „FREE ROBUX“, „ADMIN“, nesľubuj veci, ktoré hra nemá. Zavádzajúce videá Roblox zamietne
  a započíta ich do mesačného limitu 3 nahratí videa.
* **Žiadne skutočné osoby** (youtuberi, celebrity, spolužiaci) ani ich podoba.
* **Žiadne cudzie postavičky a značky** (Pokémon, Mario, Minecraft, Disney, logo Robloxu…) –
  porušuje to autorské práva a pravidlá Robloxu (IP guidelines).
* Text v thumbnailoch daj **hore alebo do stredu** – spodok môže prekryť počet hráčov.
* Všetky obrázky sú moderované – obsah musí byť vhodný pre všetky vekové kategórie.

---

## 3. Ikona hry

**Veľkosť:** 512×512 · **Pozadie:** plné, farebné · **Kam:** Creator Hub → hra → Basic Settings → Icon ·
**Config:** – (nevkladá sa)

Ikona sa zobrazuje aj v malom (150×150), takže jeden veľký jasný motív, bez textu.

```text
Square game icon for a kids' Roblox game about buying mystery junk boxes and flipping them for profit.
A cheerful cardboard mystery box bursting open in the center, golden light and sparkles shooting out,
a shiny gold coin, a tiny wind-up robot and a vintage camera popping out of it, a cute smiling cartoon
price tag tied to the box. Background: warm orange-to-yellow radial gradient with soft market-stall
bunting flags at the top edge. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic,
chunky rounded shapes, soft studio lighting, saturated cheerful colors, thick clean outlines, very
readable silhouette at small size, centered composition, no text, no watermark. 1:1, 512x512.
Negative: text, letters, logo, watermark, dark colors, realistic photo, clutter, tiny details, real person, copyrighted characters
```

Alternatíva (ak chceš ukázať postavičku):

```text
Square game icon: a happy blocky cartoon toy-like character (generic, not a real Roblox avatar) wearing
a blue work apron, holding a sparkling repaired antique pocket watch in one hand and a scrub sponge in
the other, standing behind an open glowing mystery box, gold coins flying. Bright turquoise background
with soft bokeh lights. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky
rounded shapes, soft lighting, thick clean outlines, centered, no text, no watermark. 1:1, 512x512.
Negative: text, letters, logo, watermark, realistic human, celebrity, creepy face, dark lighting, clutter
```

---

## 4. Thumbnaily hry (1920×1080)

**Veľkosť:** 1920×1080 (16:9), pod 3 MB · **Pozadie:** plná scéna · **Kam:** Creator Hub → hra →
Basic Settings → Thumbnails (a voliteľne Ads Manager ako reklamný obrázok) · **Config:** –

> ⚠️ **Dôležité:** Thumbnail musí vyzerať ako **tvoja skutočná hra**. Najlepší postup:
> 1. V Studiu spusti *Play*, stlač **Shift + P** (voľná kamera) a urob pekný screenshot námestia.
> 2. Ten použi ako **referenčný obrázok** pre AI („image-to-image“, sila 30–50 %), aby AI len
>    vylepšila svetlo a farby, ale zachovala skutočné stánky, farby a rozloženie.
> 3. Ak generuješ úplne od nuly, porovnaj výsledok s hrou – stánky v hre sú **oranžový
>    (Bazár), modrý (Dielňa) a zelený (Predajný pult)**, tabuľa TOP 10, darčeky na námestí.
>
> Text (napr. „SK + EN“, „ZIMNÝ FESTIVAL“) radšej dopíš sám v Canve – bude ostrý a bez chýb.
> Text nedávaj do spodnej pätiny obrázka.

### Thumbnail 1 – Bazárové námestie (hlavný)

```text
Wide 16:9 cinematic screenshot-style scene of a cheerful cartoon market plaza in a kids' Roblox game,
sunny afternoon. Three colorful market stalls arranged in a semicircle: an ORANGE striped-awning
bazaar stall stacked with cardboard mystery boxes on the left, a BLUE workbench repair station with
tools, sponges and soap bubbles in the middle, and a GREEN sell counter with a cash register and coin
piles on the right. Bunting flags, potted plants, a big wooden leaderboard sign (blank, no readable
text) at the side, a few friendly blocky toy-like player characters walking around, small cute pets
following them. Gentle depth of field, soft warm lighting, clean blue sky. STYLE: bright friendly
cartoon 3D render, Roblox-like blocky toy aesthetic, saturated cheerful colors, soft shadows, no text,
no watermark. 1920x1080.
Negative: text, letters, numbers, logo, watermark, realistic people, celebrity, weapons, night, horror, dark, blurry, clutter in the bottom area
```

### Thumbnail 2 – Slučka „kúp → oprav → predaj“

```text
Wide 16:9 illustration showing three moments left to right connected by a curved glowing arrow path:
(1) a blocky cartoon toy-like kid opening a cardboard mystery box with sparkles and a dusty old
gramophone popping out, (2) the same kid scrubbing the gramophone at a blue workbench with a sponge,
soap bubbles and a small progress ring above it, the gramophone becoming shiny, (3) the kid at a
green sell counter happily receiving a pile of gold coins. Bright market plaza background, slightly
blurred. Clear readable storytelling, big shapes. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, soft lighting, saturated colors, thick clean outlines, no text, no
watermark. 1920x1080.
Negative: text, letters, numbers, logo, watermark, realistic people, weapons, scary, dark lighting, clutter
```

### Thumbnail 3 – Zvieratká-pomocníci

```text
Wide 16:9 scene: a group of adorable chibi pets standing proudly on the cobblestone of a colorful
cartoon market plaza: a puppy, a kitten, a bunny, a hamster, a fox, an owl, a panda, a small friendly
baby dragon, a pastel unicorn and a warm orange-red phoenix chick with soft glowing feathers. Two
pets have small golden stars floating above their heads. Behind them, a cracked-open speckled egg and
a golden egg on a pedestal glowing softly. Sunny light, sparkles. STYLE: bright friendly cartoon 3D
render, Roblox-like toy aesthetic, big shiny eyes, rounded shapes, soft lighting, saturated
cheerful colors, no text, no watermark. 1920x1080.
Negative: text, letters, numbers, logo, watermark, realistic animals, scary, sharp teeth, fire damage, dark, copyrighted characters
```

### Thumbnail 4 – Lesklé (✨ shiny) a legendárne poklady

```text
Wide 16:9 close-up hero shot of a treasure reveal moment: an ornate royal treasure chest with gold
trim open on a wooden table, golden light rays pouring out, floating around it a jeweled music box,
an antique grandfather clock, a golden samovar, a rolled-up pirate map and a dragon egg statue, one
item surrounded by rainbow sparkles to show it is extra shiny. Confetti in the air. Warm market stall
background with soft bokeh. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic,
glossy materials, soft studio lighting, saturated colors, no text, no watermark. 1920x1080.
Negative: text, letters, numbers, logo, watermark, realistic photo, weapons, skulls, dark, clutter, real person
```

### Thumbnail 5 – Sezónny: Zimný festival (používaj 1. 12. – 6. 1.)

```text
Wide 16:9 cozy winter version of a cartoon market plaza: three stalls (orange, blue, green) covered
with soft snow and string lights, a big wrapped winter gift box with a red ribbon glowing in the
center, a magic snowman with a friendly smile, ice skates, a snow globe and gingerbread cookies
displayed around it, blocky toy-like kid characters in scarves, gentle snowfall, warm golden lamp
light against a twilight-blue sky. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, cozy and joyful, soft lighting, no text, no watermark. 1920x1080.
Negative: text, letters, numbers, logo, watermark, real Santa photo, realistic people, scary, dark night, blizzard
```

### Thumbnail 6 – Sezónny: Halloween (používaj 15. 10. – 2. 11.)

```text
Wide 16:9 friendly (not scary) Halloween version of a cartoon market plaza at dusk: purple and orange
lights, cute glowing jack-o'-lanterns with happy smiles, a spooky-but-cute purple mystery box with
a pumpkin lid, a smiling Pumpkin King figure, a magician's top hat, a lucky cat statue, a ghost
lantern with a cute cartoon ghost face, a pile of candy. Blocky toy-like kid characters in simple
costumes. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, playful and cozy,
soft glow lighting, saturated purple and orange, no text, no watermark. 1920x1080.
Negative: text, letters, numbers, logo, watermark, gore, blood, skeletons, scary faces, horror, realistic, weapons
```

> 🧪 **A/B testovanie:** Nahraj aspoň 2–3 thumbnaily a v Creator Hub zapni
> **Thumbnail personalization** (záložka *Home Page*). Roblox sám ukazuje rôznym hráčom
> rôzne thumbnaily a viac zobrazuje ten, na ktorý klikajú a hrajú dlhšie.

---

## 5. Predmety (`Config.Images.Items`)

**Pre všetky predmety platí:** 512×512 PNG, **priehľadné pozadie**, jeden objekt v strede
(3/4 pohľad, mierne zhora), nahrať ako Decal / cez Asset Manager (pozri [kapitolu 2](#2-ako-nahrať-obrázky-do-robloxu-a-získať-id)),
ID vložiť do `Config.Images.Items.<TemplateId>` ako `"rbxassetid://<ID>"`.

Rarita sa prejaví v štýle:
* **Trash (bežné)** – mierne opotrebované, ale **roztomilé**, nie odporné; tlmené farby; bez žiary.
* **Rare (vzácne)** – pekne zachovalé, jemná **modrá žiara** okolo.
* **Legendary (legendárne)** – luxusné, **zlatá žiara a iskričky**.

> Hra sama pridáva rámik rarity a ✨ efekt pre lesklé predmety – na obrázku ich nemaj.

### 5.1 Bežné (Trash)

#### 🥄 Hrdzavá lyžica — `RustySpoon`
`Config.Images.Items.RustySpoon` · 512×512 · priehľadné
```text
Single game item icon: an old cartoon soup spoon with cute orange rust spots and a slightly bent
handle, still charming and toy-like, lying at a slight angle, 3/4 view. Muted grey-brown metal
colors, no glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded
shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on transparent
background, no text, no watermark. 512x512.
Negative: text, watermark, background scene, realistic photo, gross, dirty sludge, blood, knife, sharp edges, shadows on floor
```

#### 🫖 Prasknutá kanvica — `CrackedTeapot`
`Config.Images.Items.CrackedTeapot` · 512×512 · priehľadné
```text
Single game item icon: a chubby cartoon porcelain teapot with a visible zig-zag crack, a tiny chip on
the spout and faded blue flower pattern, cute and cozy, 3/4 view. Muted cream and faded blue colors,
no glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes,
soft studio lighting, thick clean outlines, centered with padding, isolated on transparent background,
no text, no watermark. 512x512.
Negative: text, watermark, background, realistic photo, broken shards everywhere, dark, steam face, clutter
```

#### 🥾 Plesnivá čižma — `MoldyBoot`
`Config.Images.Items.MoldyBoot` · 512×512 · priehľadné
```text
Single game item icon: an old cartoon brown leather hiking boot with a few cute fuzzy green moss
patches, a loose lace and a tiny mushroom sprouting from the top, funny not gross, 3/4 view. Muted
brown and soft green, no glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic,
chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, realistic photo, disgusting mold, slime, bugs, smell lines, dark
```

#### 📻 Pokazené rádio — `BrokenRadio`
`Config.Images.Items.BrokenRadio` · 512×512 · priehľadné
```text
Single game item icon: a retro 1950s cartoon tabletop radio with a bent antenna, one loose knob,
a small dent and a little spring popping out of the side, round speaker grille, 3/4 view. Faded
mint-green and cream plastic, no glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding,
isolated on transparent background, no text, no watermark. 512x512.
Negative: text, letters on dial, brand logo, watermark, background, realistic photo, smoke, fire, sparks, dark
```

#### 🏺 Otlčená váza — `ChippedVase`
`Config.Images.Items.ChippedVase` · 512×512 · priehľadné
```text
Single game item icon: a round-bellied cartoon clay vase with a small chip missing from the rim and
faded terracotta zig-zag pattern, a little dusty, 3/4 view. Muted terracotta orange and beige, no glow.
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio
lighting, thick clean outlines, centered with padding, isolated on transparent background, no text, no
watermark. 512x512.
Negative: text, watermark, background, realistic photo, flowers, shattered pieces, dark, clutter
```

#### 🔔 Ohnutý zvonček — `BentBell`
`Config.Images.Items.BentBell` · 512×512 · priehľadné
```text
Single game item icon: a small cartoon bicycle bell with a slightly bent lever and a dented dome,
chipped red paint showing silver metal underneath, mounting clamp visible, 3/4 view. Muted red and
grey, no glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded
shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on transparent
background, no text, no watermark. 512x512.
Negative: text, watermark, background, bicycle, realistic photo, dark, motion lines, clutter
```

#### 🦆 Pískacia kačička — `SqueakyDuck`
`Config.Images.Items.SqueakyDuck` · 512×512 · priehľadné
```text
Single game item icon: a classic cartoon rubber duck toy, slightly faded yellow with a scuffed orange
beak and a tiny patch, big friendly eyes, cheerful expression, 3/4 view. Soft muted yellow, no glow.
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft
studio lighting, thick clean outlines, centered with padding, isolated on transparent background, no
text, no watermark. 512x512.
Negative: text, watermark, background, water, bathtub, realistic photo, creepy eyes, dark
```

#### 🍳 Otlčený kotlík — `DentedKettle`
`Config.Images.Items.DentedKettle` · 512×512 · priehľadné
```text
Single game item icon: an old cartoon camping kettle / cooking pot with two round dents, a wobbly
handle and a soot-darkened bottom, cute and rustic, 3/4 view. Muted dull copper and grey, no glow.
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio
lighting, thick clean outlines, centered with padding, isolated on transparent background, no text, no
watermark. 512x512.
Negative: text, watermark, background, fire, stove, realistic photo, dark, steam, clutter
```

### 5.2 Vzácne (Rare)

#### 📷 Starý fotoaparát — `VintageCamera`
`Config.Images.Items.VintageCamera` · 512×512 · priehľadné
```text
Single game item icon: a charming vintage 1960s cartoon film camera with brown leather texture, a
big shiny lens, silver dials and a little strap, well preserved, 3/4 view, surrounded by a soft blue
magical glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded
shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on transparent
background, no text, no watermark. 512x512.
Negative: text, brand logo, letters, watermark, background, realistic photo, flash burst, dark, clutter
```

#### 🧭 Mosadzný kompas — `BrassCompass`
`Config.Images.Items.BrassCompass` · 512×512 · priehľadné
```text
Single game item icon: an open brass pocket compass with a polished lid, a red-and-white needle and
a simple star rose (symbols only, no letters), small chain loop, 3/4 view, soft blue magical glow
around it. Warm brass and gold tones. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding,
isolated on transparent background, no text, no watermark. 512x512.
Negative: text, letters N E S W, numbers, watermark, background, map, realistic photo, dark
```

#### 🎺 Starý gramofón — `Gramophone`
`Config.Images.Items.Gramophone` · 512×512 · priehľadné
```text
Single game item icon: an antique cartoon gramophone with a big flared golden-brass horn shaped like
a flower, a wooden base, and a black vinyl record, small musical notes floating, 3/4 view, soft blue
magical glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded
shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on transparent
background, no text, no watermark. 512x512.
Negative: text, label text on record, watermark, background, realistic photo, trumpet player, dark, clutter
```

#### ⌚ Strieborné hodinky — `PocketWatch`
`Config.Images.Items.PocketWatch` · 512×512 · priehľadné
```text
Single game item icon: an elegant silver pocket watch with an open engraved lid, a white face with
simple tick marks (no numbers), delicate hands, a short silver chain curling beside it, 3/4 view,
soft blue magical glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky
rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, numbers, roman numerals, brand logo, watermark, background, realistic photo, dark
```

#### 🎮 Retro konzola — `RetroConsole`
`Config.Images.Items.RetroConsole` · 512×512 · priehľadné
```text
Single game item icon: a generic boxy retro 1980s-style toy game console in light grey with a wired
controller with a round D-pad and two colorful buttons, a cartridge plugged in (blank label), 3/4
view, soft blue magical glow. Must not resemble any real brand. STYLE: bright friendly cartoon 3D
render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, Nintendo, Sega, PlayStation, Xbox, brand logo, letters, watermark, background, TV screen, realistic photo
```

#### 🤖 Natahovací robot — `RobotToy`
`Config.Images.Items.RobotToy` · 512×512 · priehľadné
```text
Single game item icon: a cute vintage tin wind-up robot toy with a boxy body, round eyes, little
antenna, red and blue painted panels, a big brass wind-up key on its back, waving, 3/4 view, soft
blue magical glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky
rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, letters, watermark, background, weapon, laser, scary robot, realistic photo, dark
```

#### 🔭 Kapitánsky ďalekohľad — `Telescope`
`Config.Images.Items.Telescope` · 512×512 · priehľadné
```text
Single game item icon: a captain's brass collapsible spyglass telescope, extended, with polished
brass rings and a dark wooden grip, a tiny sparkle on the lens, diagonal composition, soft blue
magical glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded
shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on transparent
background, no text, no watermark. 512x512.
Negative: text, watermark, background, ship, pirate person, realistic photo, dark, clutter
```

### 5.3 Legendárne (Legendary)

#### 🕰️ Stojacie hodiny — `GrandfatherClock`
`Config.Images.Items.GrandfatherClock` · 512×512 · priehľadné
```text
Single game item icon: a majestic antique grandfather clock, tall polished mahogany case with gold
ornaments, a glass door showing a golden pendulum, a clock face with simple tick marks, slightly
stylized chunky proportions so it reads well in a square, front 3/4 view, radiant golden glow and
sparkles around it. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky
rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, numbers, roman numerals, watermark, background, room, realistic photo, dark, creepy
```

#### 🏆 Zlatý samovar — `GoldenSamovar`
`Config.Images.Items.GoldenSamovar` · 512×512 · priehľadné
```text
Single game item icon: an ornate golden samovar (traditional tea urn) with curved handles, a little
tap, engraved swirl patterns and a small teapot on top, gleaming polished gold, 3/4 view, radiant
golden glow and sparkles. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky
rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, trophy cup, realistic photo, fire, steam, dark, clutter
```

#### 🧶 Perzský koberec — `PersianRug`
`Config.Images.Items.PersianRug` · 512×512 · priehľadné
```text
Single game item icon: a richly patterned oriental rug partially rolled up, showing deep red, royal
blue and gold geometric and floral motifs, soft fringe tassels on the ends, slightly floating as if
magical, 3/4 view, radiant golden glow and sparkles. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, letters, calligraphy, watermark, background, floor, room, realistic photo, dark, yarn ball
```

#### 💎 Hracia skrinka — `JeweledMusicBox`
`Config.Images.Items.JeweledMusicBox` · 512×512 · priehľadné
```text
Single game item icon: an open jeweled music box with a gold frame, pastel pink enamel, embedded
colorful gems on the lid, a tiny spinning crystal star on top, musical notes floating out, 3/4 view,
radiant golden glow and sparkles. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding,
isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, ballerina figure, realistic photo, dark, clutter
```

#### 🥚 Dračie vajce — `DragonEgg`
`Config.Images.Items.DragonEgg` · 512×512 · priehľadné
```text
Single game item icon: a decorative dragon egg STATUE (an ornament, not a living egg) made of
emerald-green and gold scales, resting on a small golden claw-shaped stand, a gem at the top, 3/4
view, radiant golden glow and sparkles. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding,
isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, hatching, cracks, baby dragon, fire, realistic photo, dark, scary
```

> Pozor, aby sa dračie vajce (predmet) nepletlo s **vajíčkami na pets** – tu je to sochárska
> ozdoba na stojane, pets vajíčka sú mäkké, bodkované, bez stojana.

#### 🗺️ Pirátska mapa — `PirateMap`
`Config.Images.Items.PirateMap` · 512×512 · priehľadné
```text
Single game item icon: an old rolled-out treasure map on aged parchment with curled edges, a dotted
path, a little island drawing, a compass rose made only of shapes, and a big red X, a wax seal and a
small ribbon, slight 3/4 tilt, radiant golden glow and sparkles. STYLE: bright friendly cartoon 3D
render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, letters, words, numbers, watermark, background, skull and crossbones, pirate person, realistic photo, dark
```

### 5.4 ❄️ Zimný festival (iba počas udalosti 1. 12. – 6. 1.)

#### 🍪 Perníček — `GingerCookie`
`Config.Images.Items.GingerCookie` · 512×512 · priehľadné
```text
Single game item icon: a happy gingerbread man cookie with white icing smile, icing buttons and
wavy icing on arms and legs, one tiny bite missing from the foot, front view slightly tilted, warm
brown, no glow (common item). STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic,
chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, plate, realistic photo, creepy face, broken cookie, dark
```

#### 🧤 Vlnená rukavica — `WoollyMitten`
`Config.Images.Items.WoollyMitten` · 512×512 · priehľadné
```text
Single game item icon: a single cozy knitted wool mitten in red with a white snowflake and zig-zag
pattern, fluffy cuff, a few snowflakes stuck to it, 3/4 view, no glow (common item). STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting,
thick clean outlines, centered with padding, isolated on transparent background, no text, no
watermark. 512x512.
Negative: text, letters, watermark, background, hand, realistic photo, dark, pair of mittens
```

#### 🔮 Snežná guľa — `SnowGlobe`
`Config.Images.Items.SnowGlobe` · 512×512 · priehľadné
```text
Single game item icon: a magical snow globe on a carved wooden base, inside a tiny snowy village
with a little glowing house and pine trees, snowflakes swirling in the glass, 3/4 view, soft blue
magical glow (rare item). STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky
rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, crystal ball fortune teller, realistic photo, dark, cracked glass
```

#### ⛸️ Korčule — `IceSkates`
`Config.Images.Items.IceSkates` · 512×512 · priehľadné
```text
Single game item icon: a pair of classic white figure ice skates tied together by their laces, shiny
silver blades with a sparkle, fluffy pom-poms, 3/4 view, soft blue magical glow (rare item). STYLE:
bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio
lighting, thick clean outlines, centered with padding, isolated on transparent background, no text, no
watermark. 512x512.
Negative: text, brand logo, watermark, background, ice rink, legs, realistic photo, dark
```

#### ⛄ Čarovný snehuliak — `MagicSnowman`
`Config.Images.Items.MagicSnowman` · 512×512 · priehľadné
```text
Single game item icon: a magical friendly snowman figure with a carrot nose, coal-button smile, a
tiny top hat with a holly sprig, a striped scarf blowing in the wind, twinkling with icy magic
sparkles, front 3/4 view, radiant golden glow and sparkles (legendary item). STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick
clean outlines, centered with padding, isolated on transparent background, no text, no watermark.
512x512.
Negative: text, watermark, background, melting, scary face, copyrighted snowman character, realistic photo, dark
```

#### 🛷 Santove sane — `SantaSleigh`
`Config.Images.Items.SantaSleigh` · 512×512 · priehľadné
```text
Single game item icon: a small luxurious red sleigh with curly golden runners, a velvet seat and a
big sack of wrapped presents in the back, a few jingle bells, no characters or reindeer, 3/4 view,
radiant golden glow and sparkles (legendary item). STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, Santa person, reindeer, realistic photo, dark, brand logo
```

### 5.5 🎃 Halloween (iba počas udalosti 15. 10. – 2. 11.)

#### 🍬 Kôpka cukríkov — `CandyPile`
`Config.Images.Items.CandyPile` · 512×512 · priehľadné
```text
Single game item icon: a small cheerful pile of wrapped Halloween candies in orange, purple and green
wrappers, a couple of lollipops and candy corn pieces, 3/4 view, no glow (common item). STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting,
thick clean outlines, centered with padding, isolated on transparent background, no text, no
watermark. 512x512.
Negative: text, brand names, wrappers with logos, watermark, background, bowl, realistic photo, dark, scary
```

#### 🧹 Stará metla bosorky — `OldBroom`
`Config.Images.Items.OldBroom` · 512×512 · priehľadné
```text
Single game item icon: a crooked old wooden witch's broom with straw bristles tied with a purple
ribbon, a little patch and a tiny star charm hanging from it, diagonal composition, no glow (common
item). STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes,
soft studio lighting, thick clean outlines, centered with padding, isolated on transparent background,
no text, no watermark. 512x512.
Negative: text, watermark, background, witch person, realistic photo, dark, scary, cobwebs
```

#### 🏮 Lampáš duchov — `GhostLantern`
`Config.Images.Items.GhostLantern` · 512×512 · priehľadné
```text
Single game item icon: an old iron lantern with a soft teal-green glow inside where a tiny cute
smiling cartoon ghost floats, curly iron handle, 3/4 view, soft blue magical glow (rare item). Cute,
not scary. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes,
soft studio lighting, thick clean outlines, centered with padding, isolated on transparent background,
no text, no watermark. 512x512.
Negative: text, watermark, background, scary ghost, skull, horror, realistic photo, dark, fire
```

#### 🐈 Soška šťastnej mačky — `CatStatue`
`Config.Images.Items.CatStatue` · 512×512 · priehľadné
```text
Single game item icon: a small lucky black cat statue made of glossy ceramic, sitting upright with
big friendly golden eyes, a purple bow and a tiny orange pumpkin charm, 3/4 view, soft blue magical
glow (rare item). Cute, not spooky. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding,
isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, scary eyes, arched hissing cat, realistic animal photo, dark, waving lucky cat brand
```

#### 🎃 Tekvicový kráľ — `PumpkinKing`
`Config.Images.Items.PumpkinKing` · 512×512 · priehľadné
```text
Single game item icon: a jolly carved pumpkin figure wearing a small golden crown with gems, a
friendly happy carved smile glowing warm orange from inside, curly green vine, 3/4 view, radiant
golden glow and sparkles (legendary item). Cute, not scary. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, scary teeth, evil face, horror, copyrighted pumpkin king character, realistic photo, dark
```

#### 🎩 Kúzelnícky cylinder — `MagicTopHat`
`Config.Images.Items.MagicTopHat` · 512×512 · priehľadné
```text
Single game item icon: a magician's black top hat with a purple satin band, a few magical star
sparkles and a fluffy white bunny ear peeking out of it, a little magic wand leaning against it, 3/4
view, radiant golden glow and sparkles (legendary item). STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, magician person, realistic photo, dark, scary
```

---

## 6. Zvieratká – pets (`Config.Images.Pets`)

**Pre všetky pets:** 512×512 PNG, **priehľadné pozadie**, chibi štýl (veľká hlava, veľké lesklé oči),
sediaci 3/4 pohľad spredu, celé telo v obraze. Nahrať ako Decal / Asset Manager → ID do
`Config.Images.Pets.<Id>`. Hviezdičky ⭐ po fúzii pridáva hra sama – na obrázku ich nemaj.

Spoločný štýl pre pets (už je v každom prompte):
`adorable chibi pet, oversized head, big glossy friendly eyes, tiny smile, sitting, front 3/4 view`

| Rarita | Akcent |
|---|---|
| Trash (bežné) | bez žiary |
| Rare (vzácne) | jemná modrá žiara |
| Legendary (legendárne) | zlatá žiara + iskričky |

#### 🐶 Psíček — `Puppy` (bežný, bonus: peniaze)
```text
Game pet icon: an adorable chibi puppy with floppy ears, light caramel fur with a white chest patch,
wagging tail, wearing a tiny red bandana with a gold coin charm, oversized head, big glossy friendly
eyes, tiny smile, sitting, front 3/4 view, no glow. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, rounded shapes, soft studio lighting, thick clean outlines, centered with
padding, full body visible, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, realistic dog photo, sharp teeth, angry, copyrighted character, extra legs
```

#### 🐱 Mačiatko — `Kitten` (bežné, bonus: šťastie/lesk)
```text
Game pet icon: an adorable chibi grey tabby kitten with a pink nose, curled tail and a tiny
four-leaf-clover collar charm, a small sparkle near its paw, oversized head, big glossy friendly
eyes, tiny smile, sitting, front 3/4 view, no glow. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, rounded shapes, soft studio lighting, thick clean outlines, centered with
padding, full body visible, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, realistic cat photo, hissing, claws, copyrighted character, extra limbs
```

#### 🐰 Zajačik — `Bunny` (bežný, bonus: rýchlejšia oprava)
```text
Game pet icon: an adorable chibi white bunny with long pink-lined ears and a fluffy tail, holding a
tiny yellow scrub sponge with a few soap bubbles, oversized head, big glossy friendly eyes, tiny
smile, sitting, front 3/4 view, no glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, rounded shapes, soft studio lighting, thick clean outlines, centered with padding, full
body visible, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, realistic rabbit photo, scary eyes, copyrighted character, extra limbs
```

#### 🐹 Škrečok — `Hamster` (bežný, bonus: XP)
```text
Game pet icon: an adorable chubby chibi golden hamster with puffy cheeks, tiny pink paws holding a
small glowing blue star, oversized head, big glossy friendly eyes, tiny smile, sitting, front 3/4
view, no glow. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, rounded shapes,
soft studio lighting, thick clean outlines, centered with padding, full body visible, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, realistic rodent photo, cage, wheel, copyrighted character, extra limbs
```

#### 🦊 Líška — `Fox` (vzácna, bonus: peniaze)
```text
Game pet icon: an adorable chibi orange fox with a big fluffy white-tipped tail curled around it,
wearing a tiny green merchant's cap and a little coin pouch on a strap, oversized head, big glossy
friendly eyes, tiny smile, sitting, front 3/4 view, soft blue magical glow around it. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, rounded shapes, soft studio lighting, thick
clean outlines, centered with padding, full body visible, isolated on transparent background, no
text, no watermark. 512x512.
Negative: text, watermark, background, realistic fox photo, sly evil grin, sharp teeth, copyrighted character
```

#### 🦉 Sova — `Owl` (vzácna, bonus: rýchlejšia oprava)
```text
Game pet icon: an adorable round chibi brown owl with cream belly feathers and ear tufts, wearing
tiny round reading glasses and holding a little wrench in one wing, oversized head, huge glossy
friendly eyes, tiny smile, sitting, front 3/4 view, soft blue magical glow around it. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, rounded shapes, soft studio lighting, thick
clean outlines, centered with padding, full body visible, isolated on transparent background, no
text, no watermark. 512x512.
Negative: text, watermark, background, realistic owl photo, talons, scary stare, copyrighted character
```

#### 🐼 Panda — `Panda` (vzácna, bonus: XP)
```text
Game pet icon: an adorable chibi panda cub sitting and hugging a small bamboo stalk with a tiny
glowing star on its tip, round black ear and eye patches, oversized head, big glossy friendly eyes,
tiny smile, sitting, front 3/4 view, soft blue magical glow around it. STYLE: bright friendly cartoon
3D render, Roblox-like toy aesthetic, rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, full body visible, isolated on transparent background, no text, no watermark.
512x512.
Negative: text, watermark, background, realistic bear photo, scary, copyrighted kung fu panda character
```

#### 🐉 Drak — `Dragon` (legendárny, bonus: peniaze)
```text
Game pet icon: an adorable chibi baby dragon with emerald-green scales, a soft cream belly, tiny
rounded wings, little friendly horns, sitting on a small pile of gold coins, oversized head, big
glossy friendly eyes, tiny happy smile, front 3/4 view, radiant golden glow and sparkles. STYLE:
bright friendly cartoon 3D render, Roblox-like toy aesthetic, rounded shapes, soft studio lighting,
thick clean outlines, centered with padding, full body visible, isolated on transparent background,
no text, no watermark. 512x512.
Negative: text, watermark, background, fire breath, sharp teeth, claws, scary, realistic reptile, copyrighted dragon character
```

#### 🦄 Jednorožec — `Unicorn` (legendárny, bonus: šťastie/lesk)
```text
Game pet icon: an adorable chibi white unicorn foal with a pastel rainbow mane and tail, a spiral
golden horn, tiny rainbow sparkles and a four-leaf clover floating beside it, oversized head, big
glossy friendly eyes, tiny smile, sitting with legs tucked, front 3/4 view, radiant golden glow and
sparkles. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, rounded shapes, soft
studio lighting, thick clean outlines, centered with padding, full body visible, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, realistic horse photo, extra horns, extra legs, copyrighted pony character
```

#### 🦅 Fénix — `Phoenix` (legendárny, bonus: rýchlejšia oprava)
> Emoji v hre je orol 🦅, ale je to **fénix** – priateľský ohnivý vtáčik (oheň = mäkké žiariace perie, nie plamene, ktoré pália).
```text
Game pet icon: an adorable chibi phoenix chick with fluffy feathers in warm red, orange and golden
yellow, soft glowing ember-like tail feathers that look like gentle light (not dangerous fire), a
tiny golden crest, little wings raised happily, oversized head, big glossy friendly eyes, tiny smile,
sitting, front 3/4 view, radiant golden glow and sparkles. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, rounded shapes, soft studio lighting, thick clean outlines, centered with
padding, full body visible, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, watermark, background, eagle, realistic bird photo, burning, smoke, sharp talons, scary, copyrighted character
```

---

## 7. Krabice / bedne (`Config.Images.Crates`)

**Pre všetky:** 512×512 PNG, **priehľadné pozadie**, zatvorená krabica (aby bolo jasné, že obsah je tajomstvo),
3/4 pohľad zhora. Nahrať ako Decal / Asset Manager → ID do `Config.Images.Crates.<Key>`.

> Na krabici **nedávaj** nápisy „Robux“ ani ceny – krabice sa kupujú **len hernými peniazmi**.

#### 📦 Tajomná krabica — `JunkBox` ($25, úroveň 1, aj denná krabica zadarmo)
```text
Game icon of a closed cardboard mystery box, slightly worn and taped with brown tape, a big friendly
question-mark shaped sticker made of a simple shape (not a letter), a few curious objects peeking
from a small torn corner (spoon handle, rubber duck tail), little dust puffs, 3/4 top view. STYLE:
bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio
lighting, thick clean outlines, centered with padding, isolated on transparent background, no text,
no watermark. 512x512.
Negative: text, letters, price tag numbers, Robux symbol, watermark, background, open box, realistic photo, dark, trash bag
```

#### 🧰 Truhlica starožitností — `AntiqueChest` ($250, úroveň 3)
```text
Game icon of a closed antique wooden chest with polished brass corners, a round brass lock plate,
carved floral details and a faded velvet ribbon, a soft blue glow leaking from the seams, 3/4 top
view. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft
studio lighting, thick clean outlines, centered with padding, isolated on transparent background, no
text, no watermark. 512x512.
Negative: text, letters, Robux symbol, watermark, background, open chest, skull, pirate, realistic photo, dark
```

#### 👑 Kráľovský poklad — `RoyalTreasure` ($1,500, úroveň 8)
```text
Game icon of a closed royal treasure chest in deep purple velvet and polished gold trim, a small
golden crown emblem on the lid, jewels embedded on the front, warm golden light rays escaping from
the lid seams, floating sparkles, 3/4 top view. STYLE: bright friendly cartoon 3D render, Roblox-like
toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines, centered with
padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, letters, Robux symbol, watermark, background, open chest, real crown jewels photo, realistic, dark
```

#### 🎁 Zimný darček — `WinterGift` (iba Zimný festival)
```text
Game icon of a big closed winter gift box wrapped in icy-blue paper with white snowflake pattern, a
huge glossy red ribbon bow on top, a little snow cap on the lid and twinkling frost sparkles, 3/4 top
view. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft
studio lighting, thick clean outlines, centered with padding, isolated on transparent background, no
text, no watermark. 512x512.
Negative: text, letters, tag text, Robux symbol, watermark, background, Santa, realistic photo, dark
```

#### 🎃 Strašidelná krabica — `SpookyBox` (iba Halloween)
```text
Game icon of a closed cute spooky mystery box in purple and orange stripes, a small smiling
jack-o'-lantern as the lid knob, a friendly tiny cartoon bat sticker, soft purple glow leaking from
the seams, a couple of candy pieces around the base, 3/4 top view. Cute, not scary. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting,
thick clean outlines, centered with padding, isolated on transparent background, no text, no
watermark. 512x512.
Negative: text, letters, Robux symbol, watermark, background, skulls, blood, scary faces, horror, realistic photo
```

---

## 8. Vajíčka (`Config.Images.Eggs`)

**512×512 PNG, priehľadné pozadie**, jedno celé (nerozbité) vajíčko. ID do `Config.Images.Eggs.<Key>`.

#### 🥚 Vajíčko — `BasicEgg` ($500, úroveň 2)
```text
Game icon of a single smooth pet egg, soft cream color with pastel mint and pink polka dots, a tiny
heart-shaped spot, standing upright on a little nest of straw, gentle wobble motion lines, 3/4 view.
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft
studio lighting, thick clean outlines, centered with padding, isolated on transparent background, no
text, no watermark. 512x512.
Negative: text, watermark, background, cracked shell, creature inside, food, frying pan, realistic photo, dark
```

#### 🌟 Zlaté vajíčko — `GoldenEgg` ($5,000, úroveň 6)
```text
Game icon of a single gleaming golden pet egg with embossed star patterns and a few small inset
gems, standing upright on a little velvet cushion, radiant golden glow and floating sparkles, 3/4
view. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft
studio lighting, thick clean outlines, centered with padding, isolated on transparent background, no
text, no watermark. 512x512.
Negative: text, watermark, background, cracked shell, dragon egg statue with claws, realistic photo, dark
```

---

## 9. Obrázky kariet v hernom obchode (`Config.Images.Shop`)

Tieto obrázky nahradia emoji na kartách v **hernom** obchode (🛒). Sú **štvorcové, priehľadné**
(hra ich vloží na kartu). **512×512 PNG**, nahrať ako Decal / Asset Manager, ID do
`Config.Images.Shop.<Key>`.

> Na obrázky **nedávaj** ceny, „SALE“, „-50 %“, odpočítavanie ani nápisy. Ceny hra zobrazuje
> sama, živé z Robloxu. Falošné zľavy sú proti pravidlám Robloxu.

#### 🤖 VIP Robot-čistič — `VIPAutoCleaner` (Game Pass)
```text
Game shop icon: a cheerful little cleaning robot with a round dome head, big friendly LED eyes, a
golden VIP crown-shaped antenna (shape only), two arms holding a scrub brush and a sponge, soap
bubbles around it, polishing a shiny vintage camera, 3/4 view. STYLE: bright friendly cartoon 3D
render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, letters VIP, price, Robux symbol, watermark, background, scary robot, weapon, realistic photo
```

#### 🎒 +20 miest v batohu — `ExtraCapacity` (Game Pass)
```text
Game shop icon: a big bulging adventure backpack in bright orange and teal, top flap open with
collectibles peeking out (teapot, compass, rubber duck, gramophone horn), side pockets stuffed, a
small glowing plus-sign shape floating above it (shape only), 3/4 view. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean
outlines, centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, numbers, +20 text, price, Robux symbol, brand logo, watermark, background, realistic photo
```

#### ⚡ Okamžitá oprava — `InstantRepair` (Developer Product)
```text
Game shop icon: a magical golden wrench crossed with a sparkling yellow lightning bolt, a tiny burst
of stars and a few soap bubbles around them, energetic but friendly, centered. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean
outlines, centered with padding, isolated on transparent background, no text, no watermark. 512x512.
Negative: text, numbers, price, Robux symbol, watermark, background, electricity danger sign, realistic photo, dark
```

#### 💰 2x Peniaze — `MoneyBoost2x` (Developer Product)
```text
Game shop icon: two overflowing cartoon money bags side by side with gold coins bouncing out, a small
upward rocket-like swoosh trail behind them suggesting a temporary boost, a tiny friendly stopwatch
shape on the side, centered. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic,
chunky rounded shapes, soft studio lighting, thick clean outlines, centered with padding, isolated on
transparent background, no text, no watermark. 512x512.
Negative: text, x2 text, dollar sign letters, numbers, Robux symbol, real banknotes, watermark, background, realistic photo
```

#### 💵 Balík peňazí — `CashPackSmall` (Developer Product)
```text
Game shop icon: a neat stack of cartoon green play-money bills tied with a gold ribbon and a small
pile of shiny gold coins beside it, a couple of sparkles, centered. Clearly toy/game money, not real
currency. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes,
soft studio lighting, thick clean outlines, centered with padding, isolated on transparent background,
no text, no watermark. 512x512.
Negative: text, numbers, real currency, euro, dollar banknote faces, presidents, Robux symbol, watermark, background, realistic photo
```

---

## 10. Ikony Game Passov a Developer Products (512×512, kruh)

Tieto ikony sa zobrazujú v **Roblox okne nákupu** a na stránke hry (záložka Store).
**Max 512×512**, Roblox ich **oreže do kruhu** → hlavný motív drž v strednom kruhu
(priemer ~400 px), okraje vyplň pozadím. **Pozadie: plné** (farebný kruhový gradient).
**Kam:** Creator Hub → hra → **Monetization → Passes** alebo **Developer Products** → Upload Image.
**Config:** sem sa ID obrázka nevkladá; do `Config.GamePasses` / `Config.DevProducts` ide **ID pasu/produktu**.

> Tip: Môžeš použiť obrázok z kapitoly 9 a len ho položiť na farebný kruh v Canve.
> Prompty nižšie ho vyrobia rovno.

#### 🤖 VIP Robot-čistič — Game Pass `VIPAutoCleaner`
```text
Circular-crop friendly monetization icon, 1:1, 512x512: a cheerful little cleaning robot with a round
dome head, big friendly LED eyes and a small golden crown shape on top, holding a scrub brush, soap
bubbles, placed exactly in the center and fully inside the inner 75% circle. Background: royal purple
to gold radial gradient filling the whole square, soft vignette. STYLE: bright friendly cartoon 3D
render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines,
no text, no watermark.
Negative: text, VIP letters, price, Robux symbol, watermark, subject touching edges, important details in corners, scary robot
```

#### 🎒 +20 miest v batohu — Game Pass `ExtraCapacity`
```text
Circular-crop friendly monetization icon, 1:1, 512x512: a big bulging orange-and-teal adventure
backpack overflowing with cute collectibles (teapot, rubber duck, compass), centered and fully inside
the inner 75% circle. Background: sunny teal to light-green radial gradient filling the whole square.
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio
lighting, thick clean outlines, no text, no watermark.
Negative: text, numbers, +20, price, Robux symbol, brand logo, watermark, subject touching edges, clutter
```

#### ⚡ Okamžitá oprava — Developer Product `InstantRepair`
```text
Circular-crop friendly monetization icon, 1:1, 512x512: a golden wrench crossed with a sparkling
yellow lightning bolt, small star burst, centered and fully inside the inner 75% circle. Background:
bright blue to cyan radial gradient filling the whole square. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting, thick clean outlines, no text,
no watermark.
Negative: text, numbers, price, Robux symbol, watermark, warning sign, subject touching edges, dark
```

#### 💰 2x Peniaze — Developer Product `MoneyBoost2x`
```text
Circular-crop friendly monetization icon, 1:1, 512x512: two overflowing cartoon money bags with gold
coins bouncing out and a small upward swoosh, centered and fully inside the inner 75% circle.
Background: warm orange to golden-yellow radial gradient filling the whole square. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting,
thick clean outlines, no text, no watermark.
Negative: text, x2, numbers, dollar letters, Robux symbol, real banknotes, watermark, subject touching edges
```

#### 💵 Balík peňazí — Developer Product `CashPackSmall`
```text
Circular-crop friendly monetization icon, 1:1, 512x512: a neat stack of green toy play-money bills
tied with a gold ribbon next to a pile of shiny gold coins, centered and fully inside the inner 75%
circle. Background: fresh green to mint radial gradient filling the whole square. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting,
thick clean outlines, no text, no watermark.
Negative: text, numbers, real currency, euro, banknote portraits, Robux symbol, watermark, subject touching edges
```

---

## 11. Ikony odznakov – badges (512×512, kruh)

**Pre všetky odznaky:** 512×512, Roblox ich **oreže do kruhu** → navrhni ich ako okrúhly
**medailón** vyplňujúci celý štvorec (rohy dofarbi pozadím, nič dôležité v rohoch).
**Pozadie: plné.** **Kam:** Creator Hub → hra → **Engagement → Badges → Create a Badge**.
**Config:** `Config.Badges.<Id> = <Badge ID ako číslo>` (`0` = vypnuté).
Zadarmo **5 odznakov / 24 h (GMT) / hra**, ďalšie po 100 Robux → nahrávaj po 5 denne.

Odporúčaný postup, aby sa nepomýlili poradie: deň 1 = Welcome + prvé 4, deň 2 = ďalších 5, …

Farba okraja medailónu podľa náročnosti (aby hráč videl pokrok):

| Úroveň | Okraj | Odznaky |
|---|---|---|
| Ľahké | strieborný/zelený | Welcome, FirstFlip, Shiny1, FirstPet, StarTrainer |
| Stredné | modrý/bronzový | Repair50, Seller100, Crates250, Level20, Rebirth1, Festive |
| Ťažké | zlatý | Legend10, Rich, Repair500, Shiny10, Collector, Seller1000, PetMaster, SuperStar |

Spoločná časť každého promptu (už vložená):
`round badge medallion filling the frame, thick metallic rim, centered emblem inside the inner 70% circle`

#### 👋 Vitaj v Bazári — `Config.Badges.Welcome` (za prvé pripojenie)
```text
Round game achievement badge, 512x512: a round badge medallion filling the frame with a thick silver
rim; inside, a cheerful striped orange market-stall awning above a small open cardboard box with a
friendly sparkle and a waving cartoon hand shape, confetti. Centered emblem inside the inner 70%
circle, warm orange-to-yellow background. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, glossy enamel, soft studio lighting, thick clean outlines, no text, no watermark.
Negative: text, letters, numbers, watermark, details in corners, real person hand photo, dark, clutter
```

#### 🌱 Začiatočník — `FirstFlip` (predaj 1 predmet)
```text
Round game achievement badge, 512x512: a round medallion with a thick silver-green rim; inside, a
small green sprout growing out of a single gold coin, a tiny sparkle, symbolizing a first sale.
Centered emblem inside the inner 70% circle, fresh light-green background. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean
outlines, no text, no watermark.
Negative: text, letters, numbers, watermark, details in corners, realistic plant photo, dark
```

#### 🔧 Šikovné ruky — `Repair50` (oprav 50 predmetov)
```text
Round game achievement badge, 512x512: a round medallion with a thick bronze rim; inside, a blue
cartoon wrench and a yellow scrub sponge crossed, a few soap bubbles and a small shine star. Centered
emblem inside the inner 70% circle, sky-blue background. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean outlines, no text, no
watermark.
Negative: text, letters, numbers, 50, watermark, details in corners, weapon, dark
```

#### 💼 Profík z bazáru — `Seller100` (predaj 100 predmetov)
```text
Round game achievement badge, 512x512: a round medallion with a thick bronze rim; inside, a brown
merchant's briefcase with a gold clasp and a small stack of gold coins in front of a green sell
counter shape. Centered emblem inside the inner 70% circle, mint-green background. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick
clean outlines, no text, no watermark.
Negative: text, letters, numbers, 100, watermark, details in corners, real money, dark
```

#### 📦 Lovec krabíc — `Crates250` (otvor 250 krabíc)
```text
Round game achievement badge, 512x512: a round medallion with a thick bronze rim; inside, a tall
playful tower of stacked cardboard mystery boxes with the top one popping open and sparkles flying
out. Centered emblem inside the inner 70% circle, warm orange background. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean
outlines, no text, no watermark.
Negative: text, letters, numbers, question marks as letters, watermark, details in corners, dark
```

#### ✨ Lovec lesku — `Shiny1` (nájdi 1 lesklý predmet)
```text
Round game achievement badge, 512x512: a round medallion with a thick silver rim; inside, a small
vintage item (a teapot) glittering with big four-pointed sparkle stars and a soft rainbow shimmer.
Centered emblem inside the inner 70% circle, soft lavender background. STYLE: bright friendly cartoon
3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean outlines, no
text, no watermark.
Negative: text, letters, numbers, watermark, details in corners, dark, clutter
```

#### 🏆 Hľadač pokladov — `Legend10` (nájdi 10 legendárnych)
```text
Round game achievement badge, 512x512: a round medallion with a thick shiny gold rim; inside, a
golden trophy cup surrounded by tiny icons of legendary treasures (a pirate map scroll, a jeweled
music box, a grandfather clock) orbiting it, golden rays. Centered emblem inside the inner 70% circle,
deep royal-blue background. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic,
glossy enamel, soft studio lighting, thick clean outlines, no text, no watermark.
Negative: text, letters, numbers, 10, watermark, details in corners, dark, clutter
```

#### ⭐ Vychádzajúca hviezda — `Level20` (dosiahni úroveň 20)
```text
Round game achievement badge, 512x512: a round medallion with a thick bronze-blue rim; inside, a big
smiling golden star rising over a gentle hill with a small sparkly trail, like a sunrise. Centered
emblem inside the inner 70% circle, twilight purple-to-blue background. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean
outlines, no text, no watermark.
Negative: text, letters, numbers, 20, watermark, details in corners, dark night, clutter
```

#### 💰 Veľký zárobkár — `Rich` (zarob 100 000 celkovo)
```text
Round game achievement badge, 512x512: a round medallion with a thick shiny gold rim; inside, a huge
overflowing treasure pile of gold coins with a big cartoon money bag on top tied with a red ribbon,
sparkles. Centered emblem inside the inner 70% circle, emerald-green background. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick
clean outlines, no text, no watermark.
Negative: text, letters, numbers, dollar sign, Robux symbol, real banknotes, watermark, details in corners
```

#### 🔄 Nový štart — `Rebirth1` (urob 1 Nový začiatok)
```text
Round game achievement badge, 512x512: a round medallion with a thick bronze-blue rim; inside, two
friendly curved arrows forming a circle around a small sprouting golden seed with a tiny glowing
plus-shape, symbolizing a fresh start with a bonus. Centered emblem inside the inner 70% circle, sunny
sky-blue background. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, glossy
enamel, soft studio lighting, thick clean outlines, no text, no watermark.
Negative: text, letters, numbers, recycling logo, watermark, details in corners, dark
```

#### 🛠️ Majster opravár — `Repair500` (oprav 500 predmetov)
```text
Round game achievement badge, 512x512: a round medallion with a thick shiny gold rim; inside, a
golden hammer and a golden wrench crossed behind a small blue workbench, a tiny gold crown floating
above, soap bubbles and sparkles. Centered emblem inside the inner 70% circle, deep blue background.
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio
lighting, thick clean outlines, no text, no watermark.
Negative: text, letters, numbers, 500, watermark, details in corners, weapon, dark
```

#### 🌈 Dúhová legenda — `Shiny10` (nájdi 10 lesklých)
```text
Round game achievement badge, 512x512: a round medallion with a thick gold rim; inside, a bright
rainbow arching over a cluster of glittering sparkle stars and a shiny gem, soft clouds at the rainbow
ends. Centered emblem inside the inner 70% circle, light-blue background. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean
outlines, no text, no watermark.
Negative: text, letters, numbers, flags, watermark, details in corners, dark
```

#### 📖 Veľký zberateľ — `Collector` (objav všetkých 21 základných predmetov – bez sviatočných)
```text
Round game achievement badge, 512x512: a round medallion with a thick shiny gold rim; inside, an open
thick collection book with colorful little item stickers on its pages (spoon, camera, clock) and a
golden bookmark ribbon, sparkles rising from the pages. Centered emblem inside the inner 70% circle,
warm red background. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, glossy
enamel, soft studio lighting, thick clean outlines, no text, no watermark.
Negative: text, letters, readable words, numbers, watermark, details in corners, dark
```

#### 👑 Kráľ trhu — `Seller1000` (predaj 1000 predmetov)
```text
Round game achievement badge, 512x512: a round medallion with a thick shiny gold rim and small gems;
inside, a jeweled golden crown resting on top of a striped market-stall awning, gold coins around it.
Centered emblem inside the inner 70% circle, royal purple background. STYLE: bright friendly cartoon
3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean outlines, no
text, no watermark.
Negative: text, letters, numbers, 1000, watermark, details in corners, real crown photo, dark
```

#### 🐾 Kamoš zvieratiek — `FirstPet` (vyliahni 1 pet)
```text
Round game achievement badge, 512x512: a round medallion with a thick silver-green rim; inside, a
cracked pastel polka-dot egg with a cute chibi puppy face peeking out, a pink paw print and a little
heart. Centered emblem inside the inner 70% circle, soft pink background. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean
outlines, no text, no watermark.
Negative: text, letters, numbers, watermark, details in corners, realistic animal, dark
```

#### 🐉 Pán zvierat — `PetMaster` (vyliahni 25 pets)
```text
Round game achievement badge, 512x512: a round medallion with a thick shiny gold rim; inside, a cute
chibi baby dragon proudly sitting in front of a small group of chibi pets (puppy, kitten, bunny, owl),
golden sparkles. Centered emblem inside the inner 70% circle, emerald background. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick
clean outlines, no text, no watermark.
Negative: text, letters, numbers, 25, watermark, details in corners, fire, sharp teeth, scary
```

#### ⭐ Tréner hviezd — `StarTrainer` (prvá fúzia na ⭐)
```text
Round game achievement badge, 512x512: a round medallion with a thick silver rim; inside, three tiny
identical chibi kittens joined by swirling magic sparkles into one bigger happy kitten with one golden
star floating above its head. Centered emblem inside the inner 70% circle, soft teal background.
STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio
lighting, thick clean outlines, no text, no watermark.
Negative: text, letters, numbers, watermark, details in corners, realistic animal, dark
```

#### 🌟 Strážca superhviezd — `SuperStar` (pet s ⭐⭐)
```text
Round game achievement badge, 512x512: a round medallion with a thick shiny gold rim; inside, a proud
chibi pastel unicorn with two big golden stars floating above its head and a radiant star burst
behind it. Centered emblem inside the inner 70% circle, deep violet background. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean
outlines, no text, no watermark.
Negative: text, letters, numbers, watermark, details in corners, copyrighted pony character, dark
```

#### 🎉 Sviatočný zberateľ — `Festive` (nájdi 6 sviatočných predmetov)
```text
Round game achievement badge, 512x512: a round medallion with a thick bronze-blue rim; inside, a
small smiling snowman and a friendly smiling jack-o'-lantern side by side under a burst of party
confetti and a little wrapped gift. Centered emblem inside the inner 70% circle, split background:
icy blue on the left fading to warm orange on the right. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, glossy enamel, soft studio lighting, thick clean outlines, no text, no
watermark.
Negative: text, letters, numbers, watermark, details in corners, scary pumpkin, horror, dark
```

---

## 12. Logo na načítavaciu obrazovku

**Veľkosť:** 1024×1024 PNG · **Pozadie:** **priehľadné** · **Kam:** Decal / Asset Manager ·
**Config:** `Config.Images.Logo = "rbxassetid://<Image ID>"`

Načítavacia obrazovka už zobrazuje **názov hry ako text** (v jazyku hráča), takže logo
má byť **znak bez textu** (logo sa pri načítaní hojdá).

```text
Game logo emblem, no text: a cheerful cardboard mystery box with its flaps open, a golden coin and a
tiny wind-up robot bouncing out, a small striped orange market awning arching above it like a crown,
sparkles around, bold rounded silhouette that reads well when small and bouncing. STYLE: bright
friendly cartoon 3D render, Roblox-like toy aesthetic, chunky rounded shapes, soft studio lighting,
thick clean dark-outline sticker look, centered with padding, isolated on transparent background, no
text, no watermark. 1:1, 1024x1024.
Negative: text, letters, numbers, watermark, background, realistic photo, thin details, dark colors, clutter
```

Voliteľná verzia **s nápisom** (na sociálne siete; text je lepšie dopísať v Canve):

```text
Wide game logo, 2:1: the words "BAZAR FLIP" in big chunky rounded 3D cartoon letters, orange and gold
with thick dark outline and glossy highlights, a small open mystery box with sparkles replacing the
dot / sitting next to the text, transparent background. STYLE: bright friendly cartoon 3D render,
Roblox-like toy aesthetic, no watermark. 2048x1024.
Negative: misspelled letters, extra letters, watermark, background, realistic, thin font
```

---

## 13. Roblox skupina (group): ikona a banner

**Ikona skupiny** · 512×512 · plné pozadie · **Kam:** roblox.com → Communities → *Create* (alebo nastavenia skupiny) ·
**Config:** ID **skupiny** (z URL skupiny) ide do `Config.Social.GroupId` (členovia dostanú +10 % peňazí).

```text
Square community emblem, 512x512: a round shield-like badge with a striped orange market awning on
top, under it a cute open mystery box with a golden coin and a sparkle, a blue wrench and green price
tag crossed behind it, bold simple shapes readable at 150x150. Background: warm orange-to-teal
gradient. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, glossy enamel, thick
clean outlines, centered, no text, no watermark.
Negative: text, letters, numbers, watermark, Roblox logo, realistic, thin details, dark colors
```

**Banner skupiny** (ak ho tvoja komunita ponúka – rozmery si over v nastaveniach skupiny; ako
východisko použi 1920×480 a dôležité veci drž v strede):

```text
Wide community banner, 4:1, 1920x480: a panoramic cheerful cartoon market plaza with an orange
bazaar stall stacked with mystery boxes, a blue workbench with soap bubbles, a green sell counter with
coin piles, string bunting flags across the top, cute chibi pets (puppy, fox, baby dragon) in the
foreground, open sky in the center area left clear for an optional title. STYLE: bright friendly
cartoon 3D render, Roblox-like toy aesthetic, soft warm lighting, saturated colors, no text, no
watermark.
Negative: text, letters, numbers, watermark, realistic people, Roblox logo, dark, clutter in the center
```

---

## 14. Banner na sociálne siete

Použi na YouTube, X (Twitter), prípadne ako obrázok k príspevkom s kódmi. Text (napr.
„Nový kód: BAZAR“) dopíš v Canve – AI text často pokazí.

> Pamätaj: **Discord, TikTok, YouTube a X majú vekové hranice (spravidla 13+)**. Ak máš menej
> rokov, nech sociálne siete spravuje rodič.

**X/Twitter header – 1500×500** (dôležité veci v strede, ľavý dolný roh prekryje profilová fotka):
```text
Wide social media header, 3:1, 1500x500: cheerful cartoon market plaza panorama at golden hour,
three colorful stalls (orange with mystery boxes, blue with repair tools and soap bubbles, green with
coins), floating sparkles and confetti, a few cute chibi pets, plenty of clean sky space in the
center-right for a title. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, soft
lighting, saturated colors, no text, no watermark.
Negative: text, letters, numbers, watermark, realistic people, Roblox logo, dark, important details in bottom-left corner
```

**YouTube banner – 2560×1440** (bezpečná zóna v strede ~1546×423 – všetko dôležité daj tam):
```text
YouTube channel art, 16:9, 2560x1440: a wide cartoon market plaza scene, the main action (an open
glowing mystery box with treasures popping out, a cute baby dragon pet and a puppy pet) concentrated
in a horizontal band across the exact center, sky and bunting flags extending to the edges as calm
filler. STYLE: bright friendly cartoon 3D render, Roblox-like toy aesthetic, soft lighting, saturated
colors, no text, no watermark.
Negative: text, letters, numbers, watermark, realistic people, Roblox logo, important details near edges, dark
```

**Štvorcový príspevok s kódom – 1080×1080** (text kódu dopíš sám):
```text
Square social post background, 1080x1080: a big shiny golden gift ticket / coupon shape floating in
the center with a blank area for text, surrounded by confetti, gold coins and a small open mystery box,
cheerful orange-to-pink gradient background. STYLE: bright friendly cartoon 3D render, Roblox-like toy
aesthetic, soft lighting, no text, no watermark.
Negative: text, letters, numbers, watermark, Robux symbol, free robux, realistic, dark
```

> ⚠️ Nikdy nepíš „FREE ROBUX“ ani nič podobné – kódy dávajú **herné** peniaze a odmeny,
> nie Robux. Bolo by to zavádzajúce a v rozpore s pravidlami.

---

## 15. Kontrolný zoznam pred nahraním

- [ ] Obrázok má správnu veľkosť (512×512 / 1920×1080 / 1024×1024).
- [ ] Ikony predmetov, pets, krabíc, vajíčok, kariet obchodu a logo majú **priehľadné pozadie**.
- [ ] Kruhové ikony (badges, pasy, produkty) majú všetko dôležité **v strede**.
- [ ] Žiadny text (okrem tých, kde je to zámer), žiadne „Robux“, ceny ani falošné zľavy.
- [ ] Žiadne skutočné osoby, cudzie postavičky ani logá značiek.
- [ ] Thumbnaily zodpovedajú tomu, čo je naozaj v hre.
- [ ] Do `Config.Images` vkladáš **Image ID** (nie Decal ID) vo formáte `"rbxassetid://123"`.
- [ ] Do `Config.Badges` vkladáš **Badge ID ako číslo** (bez úvodzoviek).
- [ ] Po vložení ID si to vyskúšaš v Studiu (*Play*) – ak vidíš emoji, ID je zlé alebo čaká na moderovanie.

### Rýchly prehľad: čo kam patrí

| Obrázok | Počet | Kam nahrať | Kam vložiť ID |
|---|---|---|---|
| Ikona hry | 1 | Basic Settings → Icon | – |
| Thumbnaily | 3–10 | Basic Settings → Thumbnails | – |
| Predmety | 33 | Development Items → Decals / Asset Manager | `Config.Images.Items.<TemplateId>` |
| Pets | 10 | Decals / Asset Manager | `Config.Images.Pets.<PetId>` |
| Krabice | 5 | Decals / Asset Manager | `Config.Images.Crates.<CrateKey>` |
| Vajíčka | 2 | Decals / Asset Manager | `Config.Images.Eggs.<EggKey>` |
| Karty obchodu | 5 | Decals / Asset Manager | `Config.Images.Shop.<Key>` |
| Ikony pasov/produktov | 5 | Monetization → Passes / Developer Products | ID pasu/produktu → `Config.GamePasses` / `Config.DevProducts` |
| Odznaky | 19 | Engagement → Badges | `Config.Badges.<Id>` (číslo) |
| Logo | 1 | Decals / Asset Manager | `Config.Images.Logo` |
| Ikona skupiny | 1 | Communities | ID skupiny → `Config.Social.GroupId` |
