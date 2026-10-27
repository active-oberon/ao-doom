MODULE A2Launch;
(* Optional hosted desktop harness; a running full A2 system uses DoomWindow.Do directly. *)
IMPORT Commands;
PROCEDURE Do*(context: Commands.Context);
VAR result: INTEGER; message: ARRAY 256 OF CHAR;
BEGIN
	Commands.Call('System.DoFile desktop.cfg', {Commands.Wait}, result, message);
	IF result # 0 THEN context.result := result; RETURN END;
	Commands.Call('WindowManager.Install', {Commands.Wait}, result, message);
	IF result # 0 THEN context.result := result; RETURN END;
	Commands.Call('System.DoFile launch.cfg', {Commands.Wait}, result, message);
	context.result := result
END Do;
END A2Launch.
