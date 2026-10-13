MODULE DoomActors;

IMPORT DoomConfig, DoomInventory, DoomFormat, GameGeometry, MathL;

TYPE State* = RECORD
	x*, y*, angle*, feet*: FLOAT64;
	sector*: SIGNED32;
	awake*, moving*, detonated*: BOOLEAN;
	walkStart*, attackStart*, attackAt*, attackUntil*, deathAt*: SIGNED64
END;

(* Trace retains the actor API while shared world geometry owns ray clipping. *)
PROCEDURE Trace*(world: GameGeometry.World; x, y, dx, dy, eye, slope, range: FLOAT64): FLOAT64;
BEGIN
	RETURN world.TraceRay(x, y, dx, dy, eye, slope, range)
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
