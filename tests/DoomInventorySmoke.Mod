MODULE DoomInventorySmoke;

IMPORT DoomConfig, DoomInventory;

PROCEDURE {TEST} ArmorDamage*;
VAR player: DoomInventory.State;
	error: ARRAY 256 OF CHAR;
BEGIN
	DoomInventory.Reset(player);
	DoomInventory.Hurt(player, 20);
	ASSERT(player.health = 80);
	DoomInventory.Reset(player);
	ASSERT(DoomInventory.Give(player, 2018));
	DoomInventory.Hurt(player, 20);
	ASSERT((player.health = 86) & (player.armor = 94));
	ASSERT(DoomInventory.Give(player, 2019));
	DoomInventory.Hurt(player, 20);
	ASSERT((player.health = 76) & (player.armor = 190));
	player.armor := 3;
	DoomInventory.Hurt(player, 20);
	ASSERT((player.health = 59) & (player.armor = 0) & (player.armorType = 0));
	DoomInventory.Hurt(player, 100);
	ASSERT(player.health = 0);
	DoomInventory.Hurt(player, 0);
	ASSERT(player.health = 0);
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	DoomInventory.Reset(player);
	ASSERT(DoomInventory.Give(player, 2018));
	DoomInventory.Hurt(player, 20);
	ASSERT((player.health = 65) & (player.armor = 70));
	ASSERT(DoomInventory.Give(player, 2019));
	DoomInventory.Hurt(player, 20);
	ASSERT((player.health = 51) & (player.armor = 144));
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error))
END ArmorDamage;

PROCEDURE {TEST} ConfiguredPickups*;
VAR player: DoomInventory.State;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load("doom-custom.yaml", error));
	DoomInventory.Reset(player);
	ASSERT((player.health = 80) & (player.ammo[DoomInventory.Bullets] = 24));
	ASSERT(DoomInventory.Give(player, 2011));
	ASSERT(player.health = 87);
	ASSERT(DoomInventory.Give(player, 2012));
	ASSERT(player.health = 90);
	ASSERT(DoomInventory.Give(player, 2014));
	ASSERT(player.health = 93);
	ASSERT(DoomInventory.Give(player, 2013));
	ASSERT(player.health = 180);
	ASSERT(DoomInventory.Give(player, 2015));
	ASSERT(player.armor = 4);
	ASSERT(DoomInventory.Give(player, 2018));
	ASSERT(player.armor = 75);
	ASSERT(DoomInventory.Give(player, 2019));
	ASSERT(player.armor = 150);
	ASSERT(DoomInventory.Give(player, 2007));
	ASSERT(player.ammo[DoomInventory.Bullets] = 27);
	ASSERT(DoomInventory.Give(player, 2048));
	ASSERT(player.ammo[DoomInventory.Bullets] = 36);
	ASSERT(DoomInventory.Give(player, 2001));
	ASSERT(player.ammo[DoomInventory.Shells] = 6);
	ASSERT(DoomInventory.Give(player, 8));
	ASSERT(player.maximum[DoomInventory.Bullets] = 300);
	ASSERT(player.maximum[DoomInventory.Cells] = 360);
	ASSERT(player.ammo[DoomInventory.Bullets] = 39);
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error))
END ConfiguredPickups;

PROCEDURE Do*;
VAR player: DoomInventory.State;
	i, count: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	DoomInventory.Reset(player);
	ASSERT((player.health = 100) & (player.armor = 0));
	ASSERT(player.ammo[DoomInventory.Bullets] = 50);
	ASSERT(player.weapons = {DoomInventory.Fist, DoomInventory.Pistol});
	ASSERT((player.keys = {}) & ~player.backpack & (player.pickups = 0));
	ASSERT(~DoomInventory.Give(player, 2011));
	ASSERT(~DoomInventory.Give(player, 2012));
	player.health := 80;
	ASSERT(DoomInventory.Give(player, 2011));
	ASSERT(player.health = 90);
	ASSERT(DoomInventory.Give(player, 2012));
	ASSERT(player.health = 100);
	ASSERT(DoomInventory.Give(player, 2014));
	ASSERT(player.health = 101);
	ASSERT(DoomInventory.Give(player, 2013));
	ASSERT(player.health = 200);
	ASSERT(DoomInventory.Give(player, 2014));
	ASSERT(player.health = 200);
	ASSERT(DoomInventory.Give(player, 2015));
	ASSERT((player.armor = 1) & (player.armorType = 1));
	ASSERT(DoomInventory.Give(player, 2018));
	ASSERT(player.armor = 100);
	ASSERT(~DoomInventory.Give(player, 2018));
	ASSERT(DoomInventory.Give(player, 2019));
	ASSERT((player.armor = 200) & (player.armorType = 2));
	ASSERT(~DoomInventory.Give(player, 2018));
	ASSERT(DoomInventory.Give(player, 2015));
	ASSERT(player.armorType = 2);
	ASSERT(DoomInventory.Give(player, 2007));
	ASSERT(DoomInventory.Give(player, 2048));
	ASSERT(player.ammo[DoomInventory.Bullets] = 110);
	ASSERT(DoomInventory.Give(player, 2008));
	ASSERT(DoomInventory.Give(player, 2049));
	ASSERT(player.ammo[DoomInventory.Shells] = 24);
	ASSERT(DoomInventory.Give(player, 2047));
	ASSERT(DoomInventory.Give(player, 17));
	ASSERT(player.ammo[DoomInventory.Cells] = 120);
	ASSERT(DoomInventory.Give(player, 2010));
	ASSERT(DoomInventory.Give(player, 2046));
	ASSERT(player.ammo[DoomInventory.Rockets] = 6);
	player.ammo[DoomInventory.Bullets] := 199;
	ASSERT(DoomInventory.Give(player, 2048));
	ASSERT(player.ammo[DoomInventory.Bullets] = 200);
	ASSERT(~DoomInventory.Give(player, 2007));
	ASSERT(DoomInventory.Give(player, 2002));
	ASSERT(DoomInventory.Chaingun IN player.weapons);
	ASSERT(~DoomInventory.Give(player, 2002));
	ASSERT(DoomInventory.Give(player, 2001));
	ASSERT(DoomInventory.Give(player, 82));
	ASSERT(player.ammo[DoomInventory.Shells] = 40);
	ASSERT(DoomInventory.Give(player, 2003));
	ASSERT(player.ammo[DoomInventory.Rockets] = 8);
	ASSERT(DoomInventory.Give(player, 2004));
	ASSERT(DoomInventory.Give(player, 2006));
	ASSERT(player.ammo[DoomInventory.Cells] = 200);
	ASSERT(DoomInventory.Give(player, 2005));
	ASSERT(~DoomInventory.Give(player, 2005));
	ASSERT(player.weapons = {0..8});
	ASSERT(DoomInventory.Give(player, 5));
	ASSERT(DoomInventory.Give(player, 6));
	ASSERT(DoomInventory.Give(player, 13));
	ASSERT(DoomInventory.Give(player, 38));
	ASSERT(DoomInventory.Give(player, 39));
	ASSERT(DoomInventory.Give(player, 40));
	ASSERT(player.keys = {0..5});
	ASSERT(DoomInventory.Give(player, 5));
	ASSERT(DoomInventory.Give(player, 8));
	ASSERT(player.backpack);
	ASSERT((player.maximum[0] = 400) & (player.maximum[1] = 100));
	ASSERT((player.maximum[2] = 600) & (player.maximum[3] = 100));
	ASSERT(player.ammo[0] = 210);
	ASSERT(DoomInventory.Give(player, 8));
	ASSERT((player.maximum[0] = 400) & (player.ammo[0] = 220));
	FOR i := 0 TO 3 DO
		player.ammo[i] := player.maximum[i]
	END;
	ASSERT(DoomInventory.Give(player, 8));
	ASSERT(~DoomInventory.Give(player, 2007));
	ASSERT(~DoomInventory.Give(player, 2008));
	ASSERT(~DoomInventory.Give(player, 2047));
	ASSERT(~DoomInventory.Give(player, 2010));
	player.health := 5;
	player.armor := 3;
	ASSERT(DoomInventory.Give(player, 83));
	ASSERT((player.health = 200) & (player.armor = 200) & (player.armorType = 2));
	player.armorType := 1;
	ASSERT(DoomInventory.Give(player, 83));
	ASSERT((player.armor = 200) & (player.armorType = 1));
	count := player.pickups;
	ASSERT(~DoomInventory.Give(player, 2022));
	ASSERT(~DoomInventory.Give(player, 2023));
	ASSERT(~DoomInventory.Give(player, 85));
	ASSERT(~DoomInventory.Give(player, 9999));
	ASSERT(player.pickups = count);
	player.health := 0;
	ASSERT(~DoomInventory.Give(player, 2014));
	DoomInventory.Reset(player);
	ASSERT((player.health = 100) & (player.pickups = 0));
	ASSERT((player.keys = {}) & (player.maximum[0] = 200));
	count := 0;
	FOR i := 0 TO 65535 DO
		IF DoomInventory.Supported(i) THEN
			INC(count)
		END
	END;
	ASSERT(count = 30);
	ConfiguredPickups;
	ArmorDamage
END Do;

END DoomInventorySmoke.
