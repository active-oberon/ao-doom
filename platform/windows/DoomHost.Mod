MODULE DoomHost;

IMPORT SYSTEM, DoomConfig, DoomInput, DoomKeys, Doom, GameSurface, GameDisplay, Inputs, DoomArgs,
	Commands, User32, Kernel32, Logging;

VAR
	windowProcess: PROCEDURE {WINAPI} (window: User32.HWND; VAR pid: SIGNED32): SIGNED32;
	clientToScreen: PROCEDURE {WINAPI} (window: User32.HWND; VAR point: User32.Point): Kernel32.BOOL;
	clipCursor: PROCEDURE {WINAPI} (rect: ADDRESS): Kernel32.BOOL;
	getClassName: PROCEDURE {WINAPI} (window: User32.HWND; VAR name: ARRAY OF CHAR; size: SIGNED32): SIGNED32;
	isWindow: PROCEDURE {WINAPI} (window: User32.HWND): Kernel32.BOOL;
	library: Kernel32.HMODULE;


TYPE
	Wheel = OBJECT (Inputs.Sink)
	VAR controls: DoomInput.Controller; focused: BOOLEAN;
		PROCEDURE &Init(input: DoomInput.Controller);
		BEGIN controls := input; focused := FALSE END Init;
		PROCEDURE Focus(value: BOOLEAN);
		BEGIN {EXCLUSIVE} focused := value END Focus;
		PROCEDURE Handle*(VAR message: Inputs.Message);
		BEGIN {EXCLUSIVE}
			IF focused & (message IS Inputs.AbsMouseMsg) THEN
				WITH message: Inputs.AbsMouseMsg DO controls.Mouse(message.keys, message.dz) END
			END
		END Handle;
	END Wheel;

	Host* = OBJECT
	VAR arguments: DoomArgs.Reader;
		presenter: GameDisplay.Presenter;
		controls: DoomInput.Controller;
		wheel: Wheel;
		window: User32.HWND;
		focused, captured, known: BOOLEAN;

		PROCEDURE &Init*(context: Commands.Context);
		BEGIN NEW(arguments, context); window := 0; focused := FALSE; captured := FALSE; known := FALSE END Init;

		PROCEDURE Next*(VAR value: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			RETURN arguments.Next(value)
		END Next;

		PROCEDURE Open*(input: DoomInput.Controller): BOOLEAN;
		VAR action, binding, result: SIGNED32; fields: ARRAY 1 OF Logging.Attr;
		BEGIN
			IF (windowProcess = NIL) OR (clientToScreen = NIL) OR (clipCursor = NIL) OR
				(getClassName = NIL) OR (isWindow = NIL) THEN RETURN FALSE END;
			FOR action := 0 TO DoomConfig.InputActions - 1 DO
				FOR binding := 0 TO DoomConfig.values.controls[action].count - 1 DO
					IF DoomKeys.VirtualKey(DoomConfig.values.controls[action].keys[binding]) = 0 THEN
						fields[0] := Logging.Int("keysym", DoomConfig.values.controls[action].keys[binding]);
						result := Doom.log.Log(Logging.LevelError, "unsupported Windows key binding", fields);
						RETURN FALSE
					END
				END
			END;
			presenter := GameDisplay.Open();
			IF presenter = NIL THEN RETURN FALSE END;
			controls := input; controls.Focus(FALSE);
			NEW(wheel, controls); Inputs.mouse.Register(wheel);
			RETURN TRUE
		END Open;

		PROCEDURE Poll*;
		VAR foreground: User32.HWND; pid, result, action, binding, key: SIGNED32;
			name: ARRAY 64 OF CHAR; active: BOOLEAN; ok: Kernel32.BOOL;
			rect: User32.Rect; origin, corner, cursor: User32.Point; buttons: SET;
			fields: ARRAY 1 OF Logging.Attr;
		BEGIN
			foreground := User32.GetForegroundWindow(); pid := 0;
			IF window = 0 THEN
				result := windowProcess(foreground, pid);
				result := getClassName(foreground, name, LEN(name));
				IF (pid = Kernel32.GetCurrentProcessId()) & (name = "Aos.Window.Class") THEN window := foreground END
			ELSIF isWindow(window) = 0 THEN controls.Stop; RETURN
			END;
			active := (window # 0) & (foreground = window);
			IF ~known OR (active # focused) THEN
				known := TRUE; focused := active; controls.Focus(active); wheel.Focus(active);
				fields[0] := Logging.Bool("focused", active);
				result := Doom.log.Log(Logging.LevelInfo, "input focus changed", fields)
			END;
			IF ~active THEN
				IF captured THEN ok := clipCursor(0); captured := FALSE END;
				RETURN
			END;
			FOR action := 0 TO DoomConfig.InputActions - 1 DO
				FOR binding := 0 TO DoomConfig.values.controls[action].count - 1 DO
					key := DoomConfig.values.controls[action].keys[binding];
					controls.Key(key, User32.GetAsyncKeyState(DoomKeys.VirtualKey(key)) >= 0)
				END
			END;
			buttons := {};
			IF User32.GetAsyncKeyState(1) < 0 THEN INCL(buttons, 0) END;
			IF User32.GetAsyncKeyState(4) < 0 THEN INCL(buttons, 1) END;
			IF User32.GetAsyncKeyState(2) < 0 THEN INCL(buttons, 2) END;
			controls.Mouse(buttons, 0);
			IF User32.GetClientRect(window, rect) = 0 THEN RETURN END;
			IF (rect.right <= 0) OR (rect.bottom <= 0) THEN RETURN END;
			origin.x := 0; origin.y := 0; corner.x := rect.right; corner.y := rect.bottom;
			IF (clientToScreen(window, origin) = 0) OR (clientToScreen(window, corner) = 0) THEN RETURN END;
			rect.left := origin.x; rect.top := origin.y; rect.right := corner.x; rect.bottom := corner.y;
			origin.x := (rect.left + rect.right) DIV 2; origin.y := (rect.top + rect.bottom) DIV 2;
			IF User32.GetCursorPos(cursor) = 0 THEN RETURN END;
			IF captured THEN controls.Motion(cursor.x - origin.x, cursor.y - origin.y) END;
			ok := clipCursor(ADDRESSOF(rect)); captured := ok # 0;
			ok := User32.SetCursorPos(origin.x, origin.y)
		END Poll;

		PROCEDURE Present*(frame: GameSurface.Frame): BOOLEAN;
		BEGIN RETURN presenter.Present(frame) END Present;

		PROCEDURE Close*;
		VAR ok: Kernel32.BOOL;
		BEGIN
			wheel.Focus(FALSE); Inputs.mouse.Unregister(wheel);
			IF captured THEN ok := clipCursor(0); captured := FALSE END;
			controls.Focus(FALSE)
		END Close;
	END Host;

BEGIN
	library := Kernel32.GetModuleHandle("user32.dll");
	Kernel32.GetProcAddress(library, "GetWindowThreadProcessId", SYSTEM.VAL(ADDRESS, windowProcess));
	Kernel32.GetProcAddress(library, "ClientToScreen", SYSTEM.VAL(ADDRESS, clientToScreen));
	Kernel32.GetProcAddress(library, "ClipCursor", SYSTEM.VAL(ADDRESS, clipCursor));
	Kernel32.GetProcAddress(library, "GetClassNameA", SYSTEM.VAL(ADDRESS, getClassName));
	Kernel32.GetProcAddress(library, "IsWindow", SYSTEM.VAL(ADDRESS, isWindow))
END DoomHost.
