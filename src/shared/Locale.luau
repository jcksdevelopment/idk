--!strict
--[[
	Locale
	All player-facing text in English and Slovak. The server never sends
	display text, only keys plus arguments; the client translates them.

	Special arguments (resolved on the client):
	  "@item:<TemplateId>"   -> localized item name
	  "@rarity:<Rarity>"     -> localized rarity name
	  "@reward:<encoded>"    -> "$100 · ⚡x1 · 2x 10m" (see EncodeReward)
]]

local Items = require(script.Parent.Items)
local Types = require(script.Parent.Types)

local Locale = {}

local en: { [string]: string } = {
	-- Panels / nav
	Title_Inventory = "🎒 Bag {1}/{2}",
	Title_Bazaar = "📦 Junk Bazaar",
	Title_Shop = "🛒 Shop",
	Title_Rewards = "📜 Quests & Gifts",
	Title_Index = "📖 Collection Book",
	Title_Settings = "⚙️ Settings",
	Nav_Bag = "Bag",
	Nav_Crates = "Boxes",
	Nav_Quests = "Quests",
	Nav_Index = "Book",
	Nav_Shop = "Shop",
	Nav_Settings = "Settings",

	-- HUD
	HUD_Level = "Lv {1}",
	HUD_Workbench = "🔧 Workbench {1}/{2}",
	HUD_EmptySlot = "Empty slot",
	HUD_Boost = "💰 2x MONEY {1}",
	HUD_GetBoost = "💰 2x Money",
	HUD_Done = "Done!",
	HUD_Slots = "+2 slots",

	-- Rarities
	Rarity_Trash = "Common",
	Rarity_Rare = "Rare",
	Rarity_Legendary = "Legendary",
	Shiny = "✨ SHINY",

	-- Inventory
	Inv_Hint = "🔧 Repair at the Workbench · 💰 Sell at the Counter · ⚡ x{1}",
	Inv_Empty = "Your bag is empty!\nBuy a mystery box at the 📦 Bazaar.",
	Inv_SellAll = "💰 Sell all clean",
	Inv_Dirty = "Dirty · {1} when clean",
	Inv_Repairing = "Repairing… {1}",
	Inv_Finishing = "Almost done…",
	Inv_Clean = "✨ Clean - ready to sell!",
	Inv_Repair = "🔧 Repair {1}",
	Inv_Scrub = "🧽 Scrub!",
	Inv_SellAsIs = "Sell dirty {1}",
	Inv_Sell = "💰 Sell {1}",
	Inv_OnBench = "On the workbench",
	Inv_Upgrade = "🎒 +20 slots",

	-- Bazaar
	Bazaar_HintNear = "Cash: {1} · Open a box, fix what you find, sell it!",
	Bazaar_HintFar = "Cash: {1} · Walk to the orange 📦 Bazaar stall to buy.",
	Bazaar_Buy = "Buy {1}",
	Bazaar_Locked = "🔒 Level {1}",
	Crate_JunkBox = "Mystery Junk Box",
	Crate_AntiqueChest = "Estate Sale Chest",
	Crate_RoyalTreasure = "Royal Treasure",

	-- Shop
	Shop_Note = "Robux purchases are optional - you can earn everything by playing! Ask a grown-up first.",
	Shop_Boosts = "⚡ BOOSTS",
	Shop_Passes = "👑 GAME PASSES - forever yours",
	Shop_Soon = "Soon",
	Shop_Buy = "Buy",
	Shop_Owned = "OWNED ✓",
	Product_InstantRepair_Title = "Instant Repair",
	Product_InstantRepair_Desc = "Finish a repair right now. Unused ones are saved as ⚡ tokens.",
	Product_MoneyBoost2x_Title = "2x Money",
	Product_MoneyBoost2x_Desc = "Double sell money for 15 minutes. Stacks!",
	Product_CashPackSmall_Title = "Cash Pack",
	Product_CashPackSmall_Desc = "+$2,500 bazaar cash.",
	Pass_VIPAutoCleaner_Title = "VIP Robo-Cleaner",
	Pass_VIPAutoCleaner_Desc = "Repairs your items by itself, +2 workbench slots.",
	Pass_ExtraCapacity_Title = "+20 Bag Slots",
	Pass_ExtraCapacity_Desc = "Carry 20 more items at once.",
	Ribbon_Popular = "POPULAR",
	Ribbon_BestValue = "BEST VALUE",
	Ribbon_VIP = "VIP",

	-- Rewards
	Rewards_Daily = "🎁 Daily Gift",
	Rewards_Claim = "Claim!",
	Rewards_ComeBack = "Next gift in {1}",
	Rewards_Day = "Day {1}",
	Rewards_Quests = "📜 Today's Quests · new in {1}",
	Rewards_Done = "✓ Done",
	Quest_OpenCrates = "Open boxes ({1}×)",
	Quest_OpenManyCrates = "Open boxes ({1}×)",
	Quest_RepairItems = "Repair items ({1}×)",
	Quest_RepairManyItems = "Repair items ({1}×)",
	Quest_SellItems = "Sell items ({1}×)",
	Quest_EarnCash = "Earn {1}",
	Quest_Scrub = "Scrub ({1}×)",
	Quest_FindRare = "Find Rare items ({1}×)",
	Quest_FindLegendary = "Find a Legendary item ({1}×)",

	-- Collection
	Index_Progress = "{1}  {2}/{3}",
	Index_Claim = "Claim {1}",
	Index_Claimed = "✓ Claimed",
	Index_FindAll = "Find them all!",
	Index_Shinies = "✨ Shinies found: {1}/{2}",

	-- Settings
	Settings_Sound = "🔊 Sound effects",
	Settings_Music = "🎵 Music",
	Settings_Language = "🌍 Language",
	Settings_On = "ON",
	Settings_Off = "OFF",
	Settings_Auto = "Auto",
	Settings_SkipTutorial = "Skip tutorial",

	-- Tutorial
	Tut_1 = "Step 1/4: Walk to the orange 📦 Bazaar and buy a Mystery Box!",
	Tut_2 = "Step 2/4: Go to the blue 🔧 Workbench and press Repair!",
	Tut_3 = "Step 3/4: Wait - or tap 🧽 Scrub to clean it faster!",
	Tut_4 = "Step 4/4: Take it to the green 💰 Sell Counter and sell it!",
	Tut_Prompt = "Press E or tap the button at the stall",

	-- World
	World_Bazaar = "📦 BAZAAR",
	World_Workbench = "🔧 WORKBENCH",
	World_SellCounter = "💰 SELL",
	Prompt_Bazaar = "Buy boxes",
	Prompt_Workbench = "Repair",
	Prompt_SellCounter = "Sell",
	Prompt_Object = "Stall",

	-- Server notifications
	N_NeedBazaar = "Walk up to the 📦 Bazaar to buy boxes.",
	N_InventoryFull = "Your bag is full! Sell something first.",
	N_NotEnoughCash = "Not enough cash yet - sell some items!",
	N_CrateLocked = "Reach level {1} to open this!",
	N_Found = "You found: {1}!",
	N_NewDiscovery = "📖 New in your book: {1}!",
	N_ShinyFound = "✨ WOW, a SHINY item! It's worth 2.5×!",
	N_NeedWorkbench = "Bring it to the 🔧 Workbench first.",
	N_BenchBusy = "All workbench slots are busy.",
	N_Repaired = "{1} is sparkling clean! ✨",
	N_InstantRepaired = "⚡ {1} fixed instantly!",
	N_InstantNotConfigured = "Instant Repair is not available yet.",
	N_TokenAdded = "⚡ Instant Repair token added!",
	N_StillRepairing = "That item is still on the workbench.",
	N_NeedCounter = "Head to the 💰 Sell Counter to sell.",
	N_Sold = "Sold {1} for {2}!",
	N_SoldMany = "Sold {1} items for {2}!",
	N_NothingClean = "No clean items to sell yet.",
	N_BoostActive = "💰 2x Money for {1}!",
	N_CashAdded = "💵 {1} added!",
	N_NotOnSale = "This is not on sale yet.",
	N_AlreadyOwned = "You already own this!",
	N_LevelUp = "LEVEL {1}! Bonus {2}",
	N_QuestComplete = "📜 Quest complete! Claim your reward.",
	N_RewardClaimed = "🎁 Reward: {1}",
	N_DailyAlready = "Already claimed - come back tomorrow!",
	N_CollectionReady = "📖 You found every {1} item! Claim your reward in the book.",
	N_TutorialDone = "🎉 You're a real flipper now! Bonus: {1}",

	-- v3
	Title_Trophies = "🏆 Trophies & New Start",
	Nav_Trophies = "Trophies",
	Wheel_Title = "🎡 Lucky Wheel",
	Wheel_Spin = "SPIN! (free)",
	Wheel_Next = "Next free spin in {1}",
	Wheel_Ready = "🎡 Free spin!",
	Wheel_Note = "Always free - never for Robux.",
	Rebirth_Header = "🔄 New Start",
	Rebirth_Desc = "Start again from level 1 with {1}, but earn +{2}% money FOREVER. You keep your items, book and trophies!",
	Rebirth_Current = "New Starts: {1} · Bonus: +{2}%",
	Rebirth_Need = "Need level {1} and {2}",
	Rebirth_Button = "🔄 New Start!",
	Rebirth_Confirm = "Sure? Tap again!",
	Rebirth_Max = "Maximum reached!",
	Trophy_Equip = "Wear title",
	Trophy_Equipped = "✓ Wearing",
	Trophy_NoTitle = "No title",
	HUD_Bonus = "📈 ×{1}",
	HUD_Friends = "👫 +{1}%",
	Stat_ItemsSold = "Sell items: {1}",
	Stat_ItemsRepaired = "Repair items: {1}",
	Stat_CratesOpened = "Open boxes: {1}",
	Stat_ShiniesFound = "Find shiny items: {1}",
	Stat_LegendariesFound = "Find Legendary items: {1}",
	Stat_Level = "Reach level {1}",
	Stat_LifetimeEarned = "Earn {1} in total",
	Stat_Rebirths = "Do a New Start: {1}×",
	Stat_Collection = "Discover items: {1}",
	Ach_FirstFlip = "Rookie Flipper",
	Ach_Repair50 = "Handy Helper",
	Ach_Seller100 = "Bazaar Pro",
	Ach_Crates250 = "Box Hunter",
	Ach_Shiny1 = "Shiny Spotter",
	Ach_Legend10 = "Treasure Seeker",
	Ach_Level20 = "Rising Star",
	Ach_Rich = "Big Earner",
	Ach_Rebirth1 = "Fresh Start",
	Ach_Repair500 = "Master Mechanic",
	Ach_Shiny10 = "Rainbow Legend",
	Ach_Collector = "Grand Collector",
	Ach_Seller1000 = "Market Tycoon",
	N_Achievement = "🏆 Trophy unlocked: {1}! {2}",
	N_Rebirth = "🔄 NEW START! +{1}% money forever!",
	N_RebirthNotReady = "Not yet: you need level {1} and {2}.",
	N_WheelWait = "The wheel is resting - come back in {1}!",
	N_WheelWin = "🎡 You won: {1}!",
	N_FriendBonus = "👫 Playing with friends: +{1}% money!",
	-- v4
	Title_Pets = "🐾 Pet Helpers {1}/{2}",
	Nav_Pets = "Pets",
	Pets_Eggs = "🥚 Hatch an egg (in-game cash only)",
	Pets_Hatch = "Hatch {1}",
	Pets_Locked = "🔒 Level {1}",
	Pets_Equipped = "Following you: {1}/{2}",
	Pets_Equip = "Follow me!",
	Pets_Unequip = "Rest",
	Pets_Sell = "Send home {1}",
	Pets_Empty = "No pets yet - hatch an egg above!",
	Pets_Bonus_Money = "+{1}% money",
	Pets_Bonus_Repair = "-{1}% repair time",
	Pets_Bonus_XP = "+{1}% XP",
	Pets_Bonus_Luck = "+{1}% shiny chance",
	Pets_Total = "Team bonus: {1}",
	Egg_BasicEgg = "Pet Egg",
	Egg_GoldenEgg = "Golden Egg",
	Pet_Puppy = "Puppy",
	Pet_Kitten = "Kitten",
	Pet_Bunny = "Bunny",
	Pet_Hamster = "Hamster",
	Pet_Fox = "Fox",
	Pet_Owl = "Owl",
	Pet_Panda = "Panda",
	Pet_Dragon = "Dragon",
	Pet_Unicorn = "Unicorn",
	Pet_Phoenix = "Phoenix",
	Event_Winter = "❄️ Winter Festival",
	Event_Limited = "LIMITED!",
	Crate_WinterGift = "Winter Gift",
	Index_Event = "{1}  {2}/{3}",
	Ach_FirstPet = "Pet Friend",
	Ach_PetMaster = "Pet Master",
	Stat_PetsHatched = "Hatch pets: {1}",
	N_PetHatched = "🐾 A new friend: {1}!",
	N_PetsFull = "You have too many pets - send one home first.",
	N_PetsEquipFull = "Only {1} pets can follow you at once.",
	N_PetSold = "{1} went home happy. +{2}",
	N_EggLocked = "Reach level {1} to hatch this egg!",
	N_EventOver = "This event is over - see you next time!",
	Set_Dino = "🦖 Dino Dig",
	Crate_DinoDig = "Dino Dig Crate",
	Ach_DinoHunter = "Dino Hunter",
	Stat_DinoItems = "Find Dino Dig items: {1}",
	Set_Vault = "🏛️ Treasure Vault",
	Set_Galaxy = "🚀 Galaxy Junk",
	Crate_VaultChest = "Vault Chest",
	Crate_GalaxyCapsule = "Galaxy Capsule",
	Bazaar_NeedsRebirth = "🔒 New Start ×{1}",
	N_CrateNeedsRebirth = "Do {1} New Start(s) to open this market!",
	Ach_VaultKeeper = "Vault Keeper",
	Ach_GalaxyExplorer = "Galaxy Explorer",
	Stat_VaultItems = "Find Treasure Vault items: {1}",
	Stat_GalaxyItems = "Find Galaxy Junk items: {1}",
	Title_Upgrades = "🛠️ Workshop Upgrades",
	Nav_Upgrades = "Upgrades",
	Upg_Level = "Lv {1}/{2}",
	Upg_Buy = "Upgrade {1}",
	Upg_Max = "MAX ✓",
	Upg_Note = "Upgrades are yours forever - even after a New Start!",
	Upg_Next = "Now {1} → next {2}",
	Upg_SellBonus = "Haggling",
	Upg_SellBonus_Desc = "+{1}% sell money",
	Upg_RepairSpeed = "Better Tools",
	Upg_RepairSpeed_Desc = "-{1}% repair time",
	Upg_Backpack = "Bigger Backpack",
	Upg_Backpack_Desc = "+{1} bag slots",
	Upg_Workbench = "Extra Workbench",
	Upg_Workbench_Desc = "+{1} repair slots",
	Upg_Luck = "Lucky Charm",
	Upg_Luck_Desc = "+{1}% shiny chance",
	Ach_Tinkerer = "Tinkerer",
	Ach_MasterWorkshop = "Workshop Master",
	Stat_UpgradeLevels = "Buy upgrade levels: {1}",
	N_UpgradeBought = "🛠️ {1} is now level {2}!",
	N_UpgradeMax = "That upgrade is already maxed!",
	HUD_Request = "🧑‍💼 Wants: {1} ×{2} · {3}",
	HUD_RequestNext = "🧑‍💼 Next customer in {1}",
	Inv_Wanted = "🧑‍💼 WANTED ×{1}!",
	N_RequestDone = "🧑‍💼 Happy customer! You got ×{1} {2}",
	N_GlobalFind = "🌟 {1} just found {2}!",
	Rewards_Weekly = "🏅 Weekly challenge · new in {1}",
	HUD_Invite = "Invite",
	HUD_Group = "👥 Group +{1}%",
	HUD_Premium = "⭐ Premium +{1}%",
	HUD_JoinGroup = "Join our group for +{1}% money!",
	N_WeeklyDone = "🏅 Weekly challenge complete! Claim your big reward in Quests.",
	N_InviteThanks = "💌 Thanks for inviting friends! Play together for a money bonus.",
	Load_Title = "Bazaar Flip",
	Load_Loading = "Loading the bazaar…",
	Load_Tip1 = "Tip: tap 🧽 Scrub to repair faster!",
	Load_Tip2 = "Tip: ✨ shiny items are worth 2.5×!",
	Load_Tip3 = "Tip: play with friends for +10% money each!",
	Load_Tip4 = "Tip: your first box every day is FREE!",
	Bazaar_Free = "🎁 FREE today!",
	N_FreeBox = "🎁 Your free box of the day! Come back tomorrow for another.",
	Ach_StarTrainer = "Star Trainer",
	Ach_SuperStar = "Superstar Keeper",
	Ach_Festive = "Party Collector",
	Stat_MaxPetStars = "Fuse a pet to ⭐ level {1}",
	Stat_EventItemsFound = "Find holiday items: {1}",
	Event_Halloween = "🎃 Spooky Halloween",
	Crate_SpookyBox = "Spooky Box",
	Settings_Codes = "🎟️ Gift code",
	Codes_Placeholder = "Type a code…",
	Codes_Redeem = "Redeem",
	N_CodeOk = "🎟️ Code redeemed! You got: {1}",
	N_CodeUsed = "This code was already used.",
	N_CodeInvalid = "That code doesn't work - check the spelling!",
	Pets_Fuse = "✨ Fuse 3 → ⭐",
	Pets_Stars = "⭐ x{1} bonus",
	N_PetFused = "⭐ {1} got a star and is stronger now!",
	N_FuseNeedThree = "You need 3 of the same pet (same stars) to fuse.",
	N_FuseMax = "This pet already has the most stars!",
}

local sk: { [string]: string } = {
	Title_Inventory = "🎒 Batoh {1}/{2}",
	Title_Bazaar = "📦 Bazár harabúrd",
	Title_Shop = "🛒 Obchod",
	Title_Rewards = "📜 Úlohy a darčeky",
	Title_Index = "📖 Zberateľská kniha",
	Title_Settings = "⚙️ Nastavenia",
	Nav_Bag = "Batoh",
	Nav_Crates = "Krabice",
	Nav_Quests = "Úlohy",
	Nav_Index = "Kniha",
	Nav_Shop = "Obchod",
	Nav_Settings = "Nastav.",

	HUD_Level = "Úr. {1}",
	HUD_Workbench = "🔧 Dielňa {1}/{2}",
	HUD_EmptySlot = "Voľné miesto",
	HUD_Boost = "💰 2x PENIAZE {1}",
	HUD_GetBoost = "💰 2x Peniaze",
	HUD_Done = "Hotovo!",
	HUD_Slots = "+2 miesta",

	Rarity_Trash = "Bežné",
	Rarity_Rare = "Vzácne",
	Rarity_Legendary = "Legendárne",
	Shiny = "✨ LESKLÉ",

	Inv_Hint = "🔧 Oprav v Dielni · 💰 Predaj pri Pulte · ⚡ x{1}",
	Inv_Empty = "Batoh je prázdny!\nKúp si tajomnú krabicu na 📦 Bazári.",
	Inv_SellAll = "💰 Predať všetko čisté",
	Inv_Dirty = "Špinavé · čisté za {1}",
	Inv_Repairing = "Opravuje sa… {1}",
	Inv_Finishing = "Skoro hotovo…",
	Inv_Clean = "✨ Čisté - môžeš predať!",
	Inv_Repair = "🔧 Opraviť {1}",
	Inv_Scrub = "🧽 Drhni!",
	Inv_SellAsIs = "Predať špinavé {1}",
	Inv_Sell = "💰 Predať {1}",
	Inv_OnBench = "Je v dielni",
	Inv_Upgrade = "🎒 +20 miest",

	Bazaar_HintNear = "Peniaze: {1} · Otvor krabicu, oprav, čo nájdeš, a predaj!",
	Bazaar_HintFar = "Peniaze: {1} · Dôjdi k oranžovému stánku 📦 Bazár.",
	Bazaar_Buy = "Kúpiť {1}",
	Bazaar_Locked = "🔒 Úroveň {1}",
	Crate_JunkBox = "Tajomná krabica",
	Crate_AntiqueChest = "Truhlica starožitností",
	Crate_RoyalTreasure = "Kráľovský poklad",

	Shop_Note = "Nákupy za Robux sú dobrovoľné - všetko získaš aj hraním! Najprv sa opýtaj rodiča.",
	Shop_Boosts = "⚡ VYLEPŠENIA",
	Shop_Passes = "👑 HERNÉ PASY - navždy tvoje",
	Shop_Soon = "Čoskoro",
	Shop_Buy = "Kúpiť",
	Shop_Owned = "MÁŠ ✓",
	Product_InstantRepair_Title = "Okamžitá oprava",
	Product_InstantRepair_Desc = "Dokonči opravu hneď. Nepoužité sa uložia ako ⚡ žetóny.",
	Product_MoneyBoost2x_Title = "2x Peniaze",
	Product_MoneyBoost2x_Desc = "Dvojnásobné peniaze z predaja na 15 minút. Dá sa sčítať!",
	Product_CashPackSmall_Title = "Balík peňazí",
	Product_CashPackSmall_Desc = "+$2,500 do peňaženky.",
	Pass_VIPAutoCleaner_Title = "VIP Robot-čistič",
	Pass_VIPAutoCleaner_Desc = "Opravuje predmety sám a pridá 2 miesta v dielni.",
	Pass_ExtraCapacity_Title = "+20 miest v batohu",
	Pass_ExtraCapacity_Desc = "Unesieš naraz o 20 predmetov viac.",
	Ribbon_Popular = "OBĽÚBENÉ",
	Ribbon_BestValue = "NAJVÝHODNEJŠIE",
	Ribbon_VIP = "VIP",

	Rewards_Daily = "🎁 Denný darček",
	Rewards_Claim = "Vyzdvihni!",
	Rewards_ComeBack = "Ďalší darček o {1}",
	Rewards_Day = "Deň {1}",
	Rewards_Quests = "📜 Dnešné úlohy · nové o {1}",
	Rewards_Done = "✓ Hotovo",
	Quest_OpenCrates = "Otvor krabice ({1}×)",
	Quest_OpenManyCrates = "Otvor krabice ({1}×)",
	Quest_RepairItems = "Oprav predmety ({1}×)",
	Quest_RepairManyItems = "Oprav predmety ({1}×)",
	Quest_SellItems = "Predaj predmety ({1}×)",
	Quest_EarnCash = "Zarob {1}",
	Quest_Scrub = "Drhni ({1}×)",
	Quest_FindRare = "Nájdi vzácne predmety ({1}×)",
	Quest_FindLegendary = "Nájdi legendárny predmet ({1}×)",

	Index_Progress = "{1}  {2}/{3}",
	Index_Claim = "Vyzdvihni {1}",
	Index_Claimed = "✓ Vyzdvihnuté",
	Index_FindAll = "Nájdi všetky!",
	Index_Shinies = "✨ Nájdené lesklé: {1}/{2}",

	Settings_Sound = "🔊 Zvuky",
	Settings_Music = "🎵 Hudba",
	Settings_Language = "🌍 Jazyk",
	Settings_On = "ZAP",
	Settings_Off = "VYP",
	Settings_Auto = "Auto",
	Settings_SkipTutorial = "Preskočiť návod",

	Tut_1 = "Krok 1/4: Choď k oranžovému 📦 Bazáru a kúp si Tajomnú krabicu!",
	Tut_2 = "Krok 2/4: Choď k modrej 🔧 Dielni a stlač Opraviť!",
	Tut_3 = "Krok 3/4: Počkaj - alebo ťukaj na 🧽 Drhni a pôjde to rýchlejšie!",
	Tut_4 = "Krok 4/4: Zanes to k zelenému 💰 Pultu a predaj to!",
	Tut_Prompt = "Stlač E alebo ťukni na tlačidlo pri stánku",

	World_Bazaar = "📦 BAZÁR",
	World_Workbench = "🔧 DIELŇA",
	World_SellCounter = "💰 PREDAJ",
	Prompt_Bazaar = "Kúpiť krabice",
	Prompt_Workbench = "Opraviť",
	Prompt_SellCounter = "Predať",
	Prompt_Object = "Stánok",

	N_NeedBazaar = "Dôjdi k 📦 Bazáru a kúp si krabicu.",
	N_InventoryFull = "Batoh je plný! Najprv niečo predaj.",
	N_NotEnoughCash = "Zatiaľ nemáš dosť peňazí - predaj niečo!",
	N_CrateLocked = "Dosiahni úroveň {1} a otvoríš to!",
	N_Found = "Nález: {1}!",
	N_NewDiscovery = "📖 Nové v knihe: {1}!",
	N_ShinyFound = "✨ WOW, LESKLÝ predmet! Má hodnotu 2,5×!",
	N_NeedWorkbench = "Najprv to zanes do 🔧 Dielne.",
	N_BenchBusy = "Všetky miesta v dielni sú obsadené.",
	N_Repaired = "{1} sa blyští! ✨",
	N_InstantRepaired = "⚡ {1} - opravené okamžite!",
	N_InstantNotConfigured = "Okamžitá oprava zatiaľ nie je dostupná.",
	N_TokenAdded = "⚡ Pridaný žetón okamžitej opravy!",
	N_StillRepairing = "Ten predmet je ešte v dielni.",
	N_NeedCounter = "Choď k 💰 Pultu a predaj to.",
	N_Sold = "Predané: {1} za {2}!",
	N_SoldMany = "Predaných predmetov: {1} za {2}!",
	N_NothingClean = "Zatiaľ nemáš žiadne čisté predmety.",
	N_BoostActive = "💰 2x peniaze na {1}!",
	N_CashAdded = "💵 Pridané {1}!",
	N_NotOnSale = "Toto sa zatiaľ nepredáva.",
	N_AlreadyOwned = "Toto už máš!",
	N_LevelUp = "ÚROVEŇ {1}! Bonus {2}",
	N_QuestComplete = "📜 Úloha splnená! Vyzdvihni si odmenu.",
	N_RewardClaimed = "🎁 Odmena: {1}",
	N_DailyAlready = "Dnes už vyzdvihnuté - príď zajtra!",
	N_CollectionReady = "📖 Máš všetky predmety ({1})! Vyzdvihni odmenu v knihe.",
	N_TutorialDone = "🎉 Si skutočný obchodník! Bonus: {1}",

	Title_Trophies = "🏆 Trofeje a Nový začiatok",
	Nav_Trophies = "Trofeje",
	Wheel_Title = "🎡 Koleso šťastia",
	Wheel_Spin = "ZATOČ! (zadarmo)",
	Wheel_Next = "Ďalšie točenie o {1}",
	Wheel_Ready = "🎡 Zatoč zadarmo!",
	Wheel_Note = "Vždy zadarmo - nikdy za Robux.",
	Rebirth_Header = "🔄 Nový začiatok",
	Rebirth_Desc = "Začni znova od úrovne 1 s {1}, ale NAVŽDY zarábaj +{2}% peňazí. Predmety, kniha aj trofeje ti ostanú!",
	Rebirth_Current = "Nové začiatky: {1} · Bonus: +{2}%",
	Rebirth_Need = "Potrebuješ úroveň {1} a {2}",
	Rebirth_Button = "🔄 Nový začiatok!",
	Rebirth_Confirm = "Naozaj? Ťukni znova!",
	Rebirth_Max = "Maximum dosiahnuté!",
	Trophy_Equip = "Nosiť titul",
	Trophy_Equipped = "✓ Nosíš",
	Trophy_NoTitle = "Bez titulu",
	HUD_Bonus = "📈 ×{1}",
	HUD_Friends = "👫 +{1}%",
	Stat_ItemsSold = "Predaj predmety: {1}",
	Stat_ItemsRepaired = "Oprav predmety: {1}",
	Stat_CratesOpened = "Otvor krabice: {1}",
	Stat_ShiniesFound = "Nájdi lesklé predmety: {1}",
	Stat_LegendariesFound = "Nájdi legendárne predmety: {1}",
	Stat_Level = "Dosiahni úroveň {1}",
	Stat_LifetimeEarned = "Zarob spolu {1}",
	Stat_Rebirths = "Urob Nový začiatok: {1}×",
	Stat_Collection = "Objav predmety: {1}",
	Ach_FirstFlip = "Začiatočník",
	Ach_Repair50 = "Šikovné ruky",
	Ach_Seller100 = "Profík z bazáru",
	Ach_Crates250 = "Lovec krabíc",
	Ach_Shiny1 = "Lovec lesku",
	Ach_Legend10 = "Hľadač pokladov",
	Ach_Level20 = "Vychádzajúca hviezda",
	Ach_Rich = "Veľký zárobkár",
	Ach_Rebirth1 = "Nový štart",
	Ach_Repair500 = "Majster opravár",
	Ach_Shiny10 = "Dúhová legenda",
	Ach_Collector = "Veľký zberateľ",
	Ach_Seller1000 = "Kráľ trhu",
	N_Achievement = "🏆 Nová trofej: {1}! {2}",
	N_Rebirth = "🔄 NOVÝ ZAČIATOK! +{1}% peňazí navždy!",
	N_RebirthNotReady = "Ešte nie: potrebuješ úroveň {1} a {2}.",
	N_WheelWait = "Koleso si oddychuje - príď o {1}!",
	N_WheelWin = "🎡 Výhra: {1}!",
	N_FriendBonus = "👫 Hráš s kamarátmi: +{1}% peňazí!",
	Title_Pets = "🐾 Zvieratká-pomocníci {1}/{2}",
	Nav_Pets = "Zvieratá",
	Pets_Eggs = "🥚 Vyliahni vajíčko (len za herné peniaze)",
	Pets_Hatch = "Vyliahnuť {1}",
	Pets_Locked = "🔒 Úroveň {1}",
	Pets_Equipped = "Chodia s tebou: {1}/{2}",
	Pets_Equip = "Poď so mnou!",
	Pets_Unequip = "Oddychuj",
	Pets_Sell = "Poslať domov {1}",
	Pets_Empty = "Zatiaľ nemáš zvieratko - vyliahni si vajíčko hore!",
	Pets_Bonus_Money = "+{1}% peňazí",
	Pets_Bonus_Repair = "-{1}% času opravy",
	Pets_Bonus_XP = "+{1}% XP",
	Pets_Bonus_Luck = "+{1}% šanca na lesklé",
	Pets_Total = "Bonus tímu: {1}",
	Egg_BasicEgg = "Vajíčko",
	Egg_GoldenEgg = "Zlaté vajíčko",
	Pet_Puppy = "Psíček",
	Pet_Kitten = "Mačiatko",
	Pet_Bunny = "Zajačik",
	Pet_Hamster = "Škrečok",
	Pet_Fox = "Líška",
	Pet_Owl = "Sova",
	Pet_Panda = "Panda",
	Pet_Dragon = "Drak",
	Pet_Unicorn = "Jednorožec",
	Pet_Phoenix = "Fénix",
	Event_Winter = "❄️ Zimný festival",
	Event_Limited = "LEN TERAZ!",
	Crate_WinterGift = "Zimný darček",
	Index_Event = "{1}  {2}/{3}",
	Ach_FirstPet = "Kamoš zvieratiek",
	Ach_PetMaster = "Pán zvierat",
	Stat_PetsHatched = "Vyliahni zvieratká: {1}",
	N_PetHatched = "🐾 Nový kamarát: {1}!",
	N_PetsFull = "Máš priveľa zvieratiek - najprv jedno pošli domov.",
	N_PetsEquipFull = "S tebou môžu chodiť naraz len {1} zvieratká.",
	N_PetSold = "{1} išlo šťastne domov. +{2}",
	N_EggLocked = "Dosiahni úroveň {1} a vyliahneš toto vajíčko!",
	N_EventOver = "Táto udalosť už skončila - uvidíme sa nabudúce!",
	Set_Dino = "🦖 Dino vykopávky",
	Crate_DinoDig = "Dino debna",
	Ach_DinoHunter = "Lovec dinosaurov",
	Stat_DinoItems = "Nájdi predmety z Dino vykopávok: {1}",
	Item_FossilTooth = "Fosílny zub",
	Item_AmberStone = "Jantárový kameň",
	Item_RaptorClaw = "Pazúr raptora",
	Item_Trilobite = "Fosília trilobita",
	Item_TRexSkull = "Lebka T-Rexa",
	Item_GoldenDino = "Zlatá socha dinosaura",
	Set_Vault = "🏛️ Pokladnica",
	Set_Galaxy = "🚀 Galaktický šrot",
	Crate_VaultChest = "Truhla z pokladnice",
	Crate_GalaxyCapsule = "Galaktická kapsula",
	Bazaar_NeedsRebirth = "🔒 Nový začiatok ×{1}",
	N_CrateNeedsRebirth = "Urob Nový začiatok ({1}×) a odomkneš tento trh!",
	Ach_VaultKeeper = "Strážca pokladnice",
	Ach_GalaxyExplorer = "Galaktický prieskumník",
	Stat_VaultItems = "Nájdi predmety z Pokladnice: {1}",
	Stat_GalaxyItems = "Nájdi predmety z Galaktického šrotu: {1}",
	Item_SilverCutlery = "Strieborný príbor",
	Item_PorcelainDoll = "Porcelánová bábika",
	Item_KnightHelmet = "Rytierska prilba",
	Item_GoldenHarp = "Zlatá harfa",
	Item_CrystalCrown = "Krištáľová koruna",
	Item_PharaohMask = "Faraónova maska",
	Item_MoonRock = "Mesačný kameň",
	Item_SatelliteDish = "Stará satelitná anténa",
	Item_RobotDog = "Robotický pes",
	Item_AlienLamp = "Mimozemská lampa",
	Item_MiniUFO = "Mini UFO",
	Item_StarAtlas = "Hviezdny atlas",
	Title_Upgrades = "🛠️ Vylepšenia dielne",
	Nav_Upgrades = "Vylepš.",
	Upg_Level = "Úr. {1}/{2}",
	Upg_Buy = "Vylepšiť {1}",
	Upg_Max = "MAX ✓",
	Upg_Note = "Vylepšenia ti ostanú navždy - aj po Novom začiatku!",
	Upg_Next = "Teraz {1} → ďalej {2}",
	Upg_SellBonus = "Zjednávanie",
	Upg_SellBonus_Desc = "+{1}% peňazí z predaja",
	Upg_RepairSpeed = "Lepšie náradie",
	Upg_RepairSpeed_Desc = "-{1}% času opravy",
	Upg_Backpack = "Väčší batoh",
	Upg_Backpack_Desc = "+{1} miest v batohu",
	Upg_Workbench = "Ďalší pracovný stôl",
	Upg_Workbench_Desc = "+{1} miest v dielni",
	Upg_Luck = "Talizman šťastia",
	Upg_Luck_Desc = "+{1}% šanca na lesklé",
	Ach_Tinkerer = "Kutil",
	Ach_MasterWorkshop = "Majster dielne",
	Stat_UpgradeLevels = "Kúp úrovne vylepšení: {1}",
	N_UpgradeBought = "🛠️ {1} má teraz úroveň {2}!",
	N_UpgradeMax = "Toto vylepšenie je už na maxime!",
	HUD_Request = "🧑‍💼 Hľadá: {1} ×{2} · {3}",
	HUD_RequestNext = "🧑‍💼 Ďalší zákazník o {1}",
	Inv_Wanted = "🧑‍💼 ŽIADANÉ ×{1}!",
	N_RequestDone = "🧑‍💼 Spokojný zákazník! Odmena ×{1} {2}",
	N_GlobalFind = "🌟 Super nález! {1}: {2}!",
	Rewards_Weekly = "🏅 Týždenná výzva · nová o {1}",
	HUD_Invite = "Pozvi",
	HUD_Group = "👥 Skupina +{1}%",
	HUD_Premium = "⭐ Premium +{1}%",
	HUD_JoinGroup = "Pridaj sa do našej skupiny za +{1}% peňazí!",
	N_WeeklyDone = "🏅 Týždenná výzva splnená! Vyzdvihni si veľkú odmenu v Úlohách.",
	N_InviteThanks = "💌 Vďaka, že pozývaš kamarátov! Spolu dostanete bonus k peniazom.",
	Load_Title = "Bazár Flip",
	Load_Loading = "Načítavam bazár…",
	Load_Tip1 = "Tip: ťukaj na 🧽 Drhni a oprava pôjde rýchlejšie!",
	Load_Tip2 = "Tip: ✨ lesklé predmety majú hodnotu 2,5×!",
	Load_Tip3 = "Tip: hraj s kamarátmi a každý ti pridá +10% peňazí!",
	Load_Tip4 = "Tip: prvá krabica každý deň je ZADARMO!",
	Bazaar_Free = "🎁 Dnes ZADARMO!",
	N_FreeBox = "🎁 Tvoja dnešná krabica zadarmo! Zajtra dostaneš ďalšiu.",
	Ach_StarTrainer = "Tréner hviezd",
	Ach_SuperStar = "Strážca superhviezd",
	Ach_Festive = "Sviatočný zberateľ",
	Stat_MaxPetStars = "Spoj zvieratko na ⭐ úroveň {1}",
	Stat_EventItemsFound = "Nájdi sviatočné predmety: {1}",
	Event_Halloween = "🎃 Strašidelný Halloween",
	Crate_SpookyBox = "Strašidelná krabica",
	Item_CandyPile = "Kôpka cukríkov",
	Item_OldBroom = "Stará metla bosorky",
	Item_GhostLantern = "Lampáš duchov",
	Item_CatStatue = "Soška šťastnej mačky",
	Item_PumpkinKing = "Tekvicový kráľ",
	Item_MagicTopHat = "Kúzelnícky cylinder",
	Settings_Codes = "🎟️ Darčekový kód",
	Codes_Placeholder = "Napíš kód…",
	Codes_Redeem = "Uplatniť",
	N_CodeOk = "🎟️ Kód uplatnený! Odmena: {1}",
	N_CodeUsed = "Tento kód už bol použitý.",
	N_CodeInvalid = "Tento kód nefunguje - skontroluj, ako je napísaný!",
	Pets_Fuse = "✨ Spoj 3 → ⭐",
	Pets_Stars = "⭐ bonus x{1}",
	N_PetFused = "⭐ {1} získal hviezdičku a je silnejší!",
	N_FuseNeedThree = "Na spojenie potrebuješ 3 rovnaké zvieratká (s rovnakými hviezdičkami).",
	N_FuseMax = "Toto zvieratko už má najviac hviezdičiek!",
	Item_GingerCookie = "Perníček",
	Item_WoollyMitten = "Vlnená rukavica",
	Item_SnowGlobe = "Snežná guľa",
	Item_IceSkates = "Korčule",
	Item_MagicSnowman = "Čarovný snehuliak",
	Item_SantaSleigh = "Santove sane",
	Item_RustySpoon = "Hrdzavá lyžica",
	Item_CrackedTeapot = "Prasknutá kanvica",
	Item_MoldyBoot = "Plesnivá čižma",
	Item_BrokenRadio = "Pokazené rádio",
	Item_ChippedVase = "Otlčená váza",
	Item_BentBell = "Ohnutý zvonček",
	Item_SqueakyDuck = "Pískacia kačička",
	Item_DentedKettle = "Otlčený kotlík",
	Item_VintageCamera = "Starý fotoaparát",
	Item_BrassCompass = "Mosadzný kompas",
	Item_Gramophone = "Starý gramofón",
	Item_PocketWatch = "Strieborné hodinky",
	Item_RetroConsole = "Retro konzola",
	Item_RobotToy = "Natahovací robot",
	Item_Telescope = "Kapitánsky ďalekohľad",
	Item_GrandfatherClock = "Stojacie hodiny",
	Item_GoldenSamovar = "Zlatý samovar",
	Item_PersianRug = "Perzský koberec",
	Item_JeweledMusicBox = "Hracia skrinka",
	Item_DragonEgg = "Dračie vajce",
	Item_PirateMap = "Pirátska mapa",
}

local tables: { [string]: { [string]: string } } = { en = en, sk = sk }
local current = "en"

function Locale.SetLanguage(language: string)
	if tables[language] then
		current = language
	end
end

function Locale.GetLanguage(): string
	return current
end

-- The game is English-first: every player starts in English. Slovak is an
-- optional language a player can pick in Settings (saved per player).
function Locale.Resolve(setting: string, _robloxLocaleId: string): string
	if tables[setting] then
		return setting
	end
	return "en"
end

local function lookup(key: string): string
	return tables[current][key] or en[key] or key
end

function Locale.ItemName(templateId: string): string
	local localized = tables[current]["Item_" .. templateId]
	if localized then
		return localized
	end
	local template = Items.Get(templateId)
	return if template then template.Name else templateId
end

function Locale.RarityName(rarity: string): string
	return lookup("Rarity_" .. rarity)
end

-- Server-side: compact, language-neutral reward encoding.
function Locale.EncodeReward(reward: Types.Reward): string
	return string.format(
		"@reward:%d;%d;%d;%d",
		math.floor(reward.Cash or 0),
		math.floor(reward.Tokens or 0),
		math.floor(reward.BoostMinutes or 0),
		math.floor(reward.XP or 0)
	)
end

local function formatCash(n: number): string
	local whole = tostring(math.floor(n))
	local formatted = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

function Locale.RewardText(reward: Types.Reward): string
	local parts = {}
	if (reward.Cash or 0) > 0 then
		table.insert(parts, formatCash(reward.Cash :: number))
	end
	if (reward.Tokens or 0) > 0 then
		table.insert(parts, "⚡x" .. tostring(reward.Tokens))
	end
	if (reward.BoostMinutes or 0) > 0 then
		table.insert(parts, "💰2x " .. tostring(reward.BoostMinutes) .. "m")
	end
	if (reward.XP or 0) > 0 then
		table.insert(parts, "⭐" .. tostring(reward.XP) .. " XP")
	end
	return table.concat(parts, " · ")
end

local function resolveArg(arg: string): string
	local item = string.match(arg, "^@item:(.+)$")
	if item then
		return Locale.ItemName(item)
	end
	local upgrade = string.match(arg, "^@upg:(.+)$")
	if upgrade then
		return lookup("Upg_" .. upgrade)
	end
	local pet = string.match(arg, "^@pet:(.+)$")
	if pet then
		return lookup("Pet_" .. pet)
	end
	local achievement = string.match(arg, "^@ach:(.+)$")
	if achievement then
		return lookup("Ach_" .. achievement)
	end
	local rarity = string.match(arg, "^@rarity:(.+)$")
	if rarity then
		return Locale.RarityName(rarity)
	end
	local cash, tokens, boost, xp = string.match(arg, "^@reward:(%d+);(%d+);(%d+);(%d+)$")
	if cash and tokens and boost and xp then
		return Locale.RewardText({
			Cash = tonumber(cash),
			Tokens = tonumber(tokens),
			BoostMinutes = tonumber(boost),
			XP = tonumber(xp),
		})
	end
	return arg
end

function Locale.T(key: string, args: { any }?): string
	local text = lookup(key)
	if args then
		text = string.gsub(text, "{(%d+)}", function(index: string): string
			local value = args[tonumber(index) :: number]
			if value == nil then
				return ""
			end
			return resolveArg(tostring(value))
		end)
	end
	return text
end

return Locale
