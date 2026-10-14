MODULE DoomCampaign;

IMPORT DoomConfig, DoomFormat, Strings;

(* Target resolves authored progression without mixing campaign choices into map activation. *)
PROCEDURE Target*(CONST current: ARRAY OF CHAR; secret: BOOLEAN; VAR target, error: ARRAY OF CHAR): BOOLEAN;
VAR i: SIGNED32;
	name: ARRAY DoomFormat.NameLength + 1 OF CHAR;
BEGIN
	IF Strings.Length(current) >= LEN(name) THEN
		COPY("Current map name is too long", error);
		RETURN FALSE
	END;
	COPY(current, name);
	FOR i := 0 TO SIGNED32(Strings.Length(name)) - 1 DO
		name[i] := CAP(name[i])
	END;
	FOR i := 0 TO SIGNED32(LEN(DoomConfig.values.campaign.routes^)) - 1 DO
		IF DoomConfig.values.campaign.routes[i].name = name THEN
			IF secret THEN
				COPY(DoomConfig.values.campaign.routes[i].secret, target)
			ELSE
				COPY(DoomConfig.values.campaign.routes[i].normal, target)
			END;
			error[0] := 0X;
			RETURN TRUE
		END
	END;
	COPY("No campaign route for map ", error);
	Strings.AppendX(error, name);
	RETURN FALSE
END Target;

END DoomCampaign.
