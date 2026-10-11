MODULE SceneBench;

IMPORT DoomConfig, Doom, GameSurface, Kernel, KernelLog;

PROCEDURE Do*;
VAR game: Doom.Game;
	frame: GameSurface.Frame;
	timer: Kernel.MilliTimer;
	i, elapsed, color: SIGNED32;
	error: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(DoomConfig.Load(DoomConfig.DefaultFile, error));
	NEW(game);
	NEW(frame, DoomConfig.values.width, DoomConfig.values.height);
	game.Render(frame);
	color := frame.Pixel(frame.width DIV 2, frame.height DIV 2);
	Kernel.SetTimer(timer, 0);
	FOR i := 1 TO 200 DO
		game.Render(frame)
	END;
	elapsed := Kernel.Elapsed(timer);
	ASSERT(frame.Pixel(frame.width DIV 2, frame.height DIV 2) = color);
	KernelLog.String("SceneBench: 200 textured frames in ");
	KernelLog.Int(elapsed, 0);
	KernelLog.String(" ms (rendering only, no display transfer).");
	KernelLog.Ln
END Do;

END SceneBench.
