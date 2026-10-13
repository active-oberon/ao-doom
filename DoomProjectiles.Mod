MODULE DoomProjectiles;

IMPORT DoomFormat, DoomActors, GameGeometry, MathL;

TYPE State* = RECORD
	owner*, weapon*: SIGNED32;
	x*, y*, z*, dx*, dy*, dz*, remaining*: FLOAT64
END;

(* Aim fixes the trajectory at launch so later player movement can dodge it. *)
PROCEDURE Aim*(VAR shot: State; x, y, z, angle: FLOAT64);
VAR distance: FLOAT64;
BEGIN
	shot.dx := x - shot.x;
	shot.dy := y - shot.y;
	shot.dz := z - shot.z;
	distance := MathL.sqrt(shot.dx * shot.dx + shot.dy * shot.dy + shot.dz * shot.dz);
	IF distance > DoomFormat.TraceTolerance THEN
		shot.dx := shot.dx / distance;
		shot.dy := shot.dy / distance;
		shot.dz := shot.dz / distance
	ELSE
		shot.dx := MathL.cos(angle);
		shot.dy := MathL.sin(angle);
		shot.dz := 0
	END
END Aim;

PROCEDURE Axis*(origin, direction, low, high: FLOAT64; VAR near, far: FLOAT64): BOOLEAN;
VAR a, b: FLOAT64;
BEGIN
	IF ABS(direction) <= DoomFormat.TraceTolerance THEN
		RETURN (origin >= low) & (origin <= high)
	END;
	a := (low - origin) / direction;
	b := (high - origin) / direction;
	near := MAX(near, MIN(a, b));
	far := MIN(far, MAX(a, b));
	RETURN near <= far
END Axis;

(* Hit sweeps the whole tick against an expanded target volume to prevent tunneling. *)
PROCEDURE Hit*(CONST shot: State; radius, height, x, y, bottom, targetRadius, targetHeight: FLOAT64;
	VAR limit: FLOAT64): BOOLEAN;
VAR near, far: FLOAT64;
BEGIN
	near := 0;
	far := limit;
	IF Axis(shot.x, shot.dx, x - targetRadius - radius, x + targetRadius + radius, near, far) &
		Axis(shot.y, shot.dy, y - targetRadius - radius, y + targetRadius + radius, near, far) &
		Axis(shot.z, shot.dz, bottom - height / 2, bottom + targetHeight + height / 2, near, far) &
		(near < limit) THEN
		limit := near;
		RETURN TRUE
	END;
	RETURN FALSE
END Hit;

(* BlastDamage checks cover before applying quantized horizontal falloff to a target footprint. *)
PROCEDURE BlastDamage*(world: GameGeometry.World; CONST shot: State; damage: SIGNED32; range: FLOAT64;
	x, y, feet, radius, height: FLOAT64): SIGNED32;
VAR dx, dy, distance, travel, center, slope: FLOAT64;
	sector: SIGNED32;
	region: GameGeometry.Sector;
BEGIN
	IF (damage <= 0) OR (range <= 0) THEN
		RETURN 0
	END;
	dx := x - shot.x;
	dy := y - shot.y;
	distance := MAX(0, ENTIER((MAX(ABS(dx), ABS(dy)) - radius) * DoomFormat.UnitsPerWorld)) / DoomFormat.UnitsPerWorld;
	IF distance >= range THEN
		RETURN 0
	END;
	travel := MathL.sqrt(dx * dx + dy * dy);
	center := feet + height / 2;
	IF travel > DoomFormat.TraceTolerance THEN
		slope := (center - shot.z) / travel;
		IF (DoomActors.Trace(world, shot.x, shot.y, dx / travel, dy / travel, shot.z, slope, travel) < travel) OR
			(DoomActors.Trace(world, x, y, -dx / travel, -dy / travel, center, -slope, travel) < travel) THEN
			RETURN 0
		END
	ELSE
		sector := world.Locate(shot.x, shot.y);
		IF sector < 0 THEN
			RETURN 0
		END;
		region := world.Region(sector);
		IF (shot.z <= region.floor) OR (shot.z >= region.ceiling) OR
			(center <= region.floor) OR (center >= region.ceiling) THEN
			RETURN 0
		END
	END;
	RETURN MAX(0, SIGNED32(ENTIER(damage * (1 - distance / range))))
END BlastDamage;

(* Trace clips flight against sector planes and openings, independently of movement-blocking flags. *)
PROCEDURE Trace*(world: GameGeometry.World; CONST shot: State; radius, height, range: FLOAT64): FLOAT64;
VAR wall: GameGeometry.Wall;
	front, back: GameGeometry.Sector;
	i, sector: SIGNED32;
	near, distance, plane, width, sx, sy, denominator, low, high, z: FLOAT64;
BEGIN
	sector := world.Locate(shot.x + shot.dx * DoomFormat.TraceTolerance, shot.y + shot.dy * DoomFormat.TraceTolerance);
	IF sector < 0 THEN
		RETURN 0
	END;
	near := 0;
	FOR i := 0 TO MIN(world.Count(), DoomFormat.MaximumTraceHits) - 1 DO
		front := world.Region(sector);
		z := shot.z + shot.dz * near;
		IF (z - height / 2 < front.floor) OR (z + height / 2 > front.ceiling) THEN
			RETURN near
		END;
		plane := range;
		IF shot.dz > DoomFormat.TraceTolerance THEN
			plane := MIN(plane, (front.ceiling - height / 2 - shot.z) / shot.dz)
		ELSIF shot.dz < -DoomFormat.TraceTolerance THEN
			plane := MIN(plane, (front.floor + height / 2 - shot.z) / shot.dz)
		END;
		IF ~world.CastSector(sector, shot.x, shot.y, shot.dx, shot.dy, near, distance, wall) THEN
			RETURN MAX(near, plane)
		END;
		sx := wall.bx - wall.ax;
		sy := wall.by - wall.ay;
		denominator := ABS(shot.dx * sy - shot.dy * sx);
		width := radius * MathL.sqrt(sx * sx + sy * sy) / denominator;
		IF distance - width >= plane THEN
			RETURN MAX(near, plane)
		END;
		IF wall.neighbor < 0 THEN
			RETURN MAX(near, distance - width)
		END;
		back := world.Region(wall.neighbor);
		low := shot.z + shot.dz * MAX(near, distance - width);
		high := shot.z + shot.dz * MIN(range, distance + width);
		IF (MIN(low, high) - height / 2 < MAX(front.floor, back.floor)) OR
			(MAX(low, high) + height / 2 > MIN(front.ceiling, back.ceiling)) THEN
			RETURN MAX(near, distance - width)
		END;
		IF (distance >= range) OR (plane <= distance) THEN
			RETURN MAX(near, plane)
		END;
		(* shortcut: faces expand along the center ray; add swept-circle corner checks with complete missile physics. *)
		sector := wall.neighbor;
		near := distance
	END;
	RETURN 0
END Trace;

END DoomProjectiles.
