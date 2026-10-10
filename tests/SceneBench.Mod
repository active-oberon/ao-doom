MODULE SceneBench;

IMPORT Doom, GameSurface, Kernel, KernelLog;

PROCEDURE Do*;
VAR game: Doom.Game;
	frame: GameSurface.Frame;
	timer: Kernel.MilliTimer;
	i, elapsed, color: SIGNED32;
BEGIN
	NEW(game);
	NEW(frame, 320, 200);
	game.Render(frame);
	color := frame.Pixel(160, 100);
	Kernel.SetTimer(timer, 0);
	FOR i := 1 TO 200 DO
		game.Render(frame)
	END;
	elapsed := Kernel.Elapsed(timer);
	ASSERT(frame.Pixel(160, 100) = color);
	KernelLog.String("SceneBench: 200 textured 320 x 200 frames in ");
	KernelLog.Int(elapsed, 0);
	KernelLog.String(" ms (rendering only, no display transfer).");
	KernelLog.Ln
END Do;

END SceneBench.
