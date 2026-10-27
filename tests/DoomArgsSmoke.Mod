MODULE DoomArgsSmoke;
IMPORT DoomArgs, Commands, KernelLog, Streams, Strings;
PROCEDURE Do*;
VAR reader: DoomArgs.Reader; value, text: ARRAY 512 OF CHAR;
	source: Streams.StringReader; context: Commands.Context;
BEGIN
	COPY('"a path with spaces.wad" "C:\doom\" ', text);
	Strings.AppendChar(text, 27X); Strings.Append(text, 'quote"inside'); Strings.AppendChar(text, 27X);
	Strings.Append(text, ' "" E1M1');
	Streams.OpenStringReader(source, text);
	NEW(context, NIL, source, NIL, NIL, NIL);
	NEW(reader, context);
	ASSERT(reader.Next(value) & (value = 'a path with spaces.wad'));
	ASSERT(reader.Next(value) & (value = 'C:\doom\'));
	ASSERT(reader.Next(value) & (value = 'quote"inside'));
	ASSERT(reader.Next(value) & (value = ''));
	ASSERT(reader.Next(value) & (value = 'E1M1'));
	ASSERT(~reader.Next(value));
	KernelLog.String('DoomArgsSmoke: quoted command context arguments passed.'); KernelLog.Ln
END Do;
END DoomArgsSmoke.
