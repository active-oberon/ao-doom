MODULE DoomActors;

IMPORT DoomConfig, DoomInventory, DoomFormat, GameGeometry, MathL;

TYPE State* = RECORD
	x*, y*, angle*, feet*: FLOAT64;
	sector*: SIGNED32;
	awake*, moving*: BOOLEAN;
	walkStart*, attackStart*, attackAt*, attackUntil*: SIGNED64
END;

(* Trace crosses two-sided windows only where the sloped ray fits their open height. *)
PROCEDURE Trace*(world: GameGeometry.World; x, y, dx, dy, eye, slope, range: FLOAT64): FLOAT64;
VAR wall: GameGeometry.Wall;
	front, back: GameGeometry.Sector;
	i, sector: SIGNED32;
	near, distance, z: FLOAT64;
BEGIN
	sector := world.Locate(x + dx * DoomFormat.TraceTolerance, y + dy * DoomFormat.TraceTolerance);
	IF sector < 0 THEN
		RETURN 0
	END;
	front := world.Region(sector);
	IF (eye <= front.floor) OR (eye >= front.ceiling) THEN
		RETURN 0
	END;
	near := 0;
	FOR i := 0 TO MIN(world.Count(), DoomFormat.MaximumTraceHits) - 1 DO
		IF ~world.CastSector(sector, x, y, dx, dy, near, distance, wall) OR (distance > range) THEN
			RETURN range
		END;
		IF wall.neighbor < 0 THEN
			RETURN distance
		END;
		front := world.Region(sector);
		back := world.Region(wall.neighbor);
		z := eye + distance * slope;
		IF (z <= MAX(front.floor, back.floor)) OR (z >= MIN(front.ceiling, back.ceiling)) THEN
			RETURN distance
		END;
		sector := wall.neighbor;
		near := distance
	END;
	RETURN 0
END Trace;

PROCEDURE TraceLimit*(world: GameGeometry.World; x, y, dx, dy, eye, range: FLOAT64): FLOAT64;
BEGIN
	RETURN Trace(world, x, y, dx, dy, eye, 0, range)
END TraceLimit;

PROCEDURE Visible(world: GameGeometry.World; CONST state: State; height, x, y, feet: FLOAT64;
	hitscan: BOOLEAN): BOOLEAN;
VAR dx, dy, distance, bottom, top, source, target, slope: FLOAT64;
BEGIN
	bottom := MAX(feet, state.feet);
	top := MIN(feet + DoomConfig.values.playerHeight, state.feet + height);
	IF ~hitscan & (bottom >= top) THEN
		RETURN FALSE
	END;
	dx := x - state.x;
	dy := y - state.y;
	distance := MathL.sqrt(dx * dx + dy * dy);
	IF distance <= DoomFormat.TraceTolerance THEN
		RETURN TRUE
	END;
	source := (bottom + top) / 2;
	target := source;
	IF hitscan THEN
		source := state.feet + height / 2;
		target := feet + DoomConfig.values.playerHeight / 2
	END;
	slope := (target - source) / distance;
	RETURN (Trace(world, state.x, state.y, dx / distance, dy / distance, source, slope, distance) >= distance) &
		(Trace(world, x, y, -dx / distance, -dy / distance, target, -slope, distance) >= distance)
END Visible;

PROCEDURE CanWake*(world: GameGeometry.World; CONST state: State; rules: DoomConfig.BehaviorSettings;
	height, x, y, feet: FLOAT64): BOOLEAN;
BEGIN
	RETURN (MathL.sqrt((x - state.x) * (x - state.x) + (y - state.y) * (y - state.y)) <= rules.sightRange) &
		Visible(world, state, height, x, y, feet, rules.hitscan OR (rules.projectile # NIL))
END CanWake;

(* Step reports a ready attack so the scene can resolve its current nearest target. *)
PROCEDURE Step*(world: GameGeometry.World; tick: SIGNED64; rules: DoomConfig.BehaviorSettings;
	radius, height, x, y, feet: FLOAT64; VAR state: State; VAR player: DoomInventory.State;
	check: GameGeometry.PositionCheck): BOOLEAN;
VAR dx, dy, distance, travel, previousX, previousY: FLOAT64;
	visible, moving, accepted, attack: BOOLEAN;
BEGIN
	IF (player.health <= 0) OR (~state.awake & ~CanWake(world, state, rules, height, x, y, feet)) THEN
		RETURN FALSE
	END;
	state.awake := TRUE;
	moving := state.moving;
	state.moving := FALSE;
	dx := x - state.x;
	dy := y - state.y;
	distance := MathL.sqrt(dx * dx + dy * dy);
	IF distance > DoomFormat.TraceTolerance THEN
		state.angle := MathL.arctan2(dy, dx)
	END;
	visible := Visible(world, state, height, x, y, feet, rules.hitscan OR (rules.projectile # NIL));
	attack := FALSE;
	IF (state.attackAt > 0) & (tick >= state.attackAt) THEN
		state.attackAt := 0;
		attack := visible & (distance <= rules.range)
	END;
	IF (player.health <= 0) OR (tick < state.attackUntil) THEN
		RETURN attack
	END;
	IF visible & (distance <= rules.range) THEN
		state.attackStart := tick;
		state.attackAt := tick + rules.windup;
		state.attackUntil := tick + rules.cycle;
		RETURN attack
	END;
	IF distance <= DoomFormat.TraceTolerance THEN
		RETURN attack
	END;
	(* shortcut: chase moves directly and slides; add route finding with complete monster AI. *)
	travel := MIN(distance, rules.speed);
	previousX := state.x;
	previousY := state.y;
	accepted := world.MovePlayerChecked(state.x, state.y, state.feet, dx * travel / distance, dy * travel / distance,
		radius, height, rules.step, check);
	IF accepted THEN
		state.sector := world.Locate(state.x, state.y);
		state.moving := (state.x # previousX) OR (state.y # previousY);
		IF state.moving & ~moving THEN
			state.walkStart := tick
		END
	END;
	RETURN attack
END Step;

END DoomActors.
