import std.stdio;
import std.json;
import std.algorithm;

import pegged.grammar;

mixin(grammar(`
Script:
	Pipeline  < Stage (:"|" Stage)*
	Stage     < Select / strlit
	Select    < (Member / Subscript)+
	Member    < :"." identifier
	Subscript < "[" number "]" / "." number

	number    <- ~[0-9]+
	strlit    <- doublequote (strinterp / strpiece)* doublequote
	strinterp <- "#{" Select "}"
	strpiece  <~ (!(doublequote / "#{") .)*
`));

alias JSONValue delegate(JSONValue) ScriptFunc;

ScriptFunc compile(ParseTree t)
{
	writefln("compile %s [%s]", t.name, t.matches);
	switch(t.name) {
	case "Script":
		return compile(t.children[0]);
	case "Script.Pipeline":
		auto stages = t.children.map!compile;
		return delegate JSONValue ( JSONValue input) {
			JSONValue val = input;
			foreach(stage; stages) {
				val = stage(val);
			}
			return val;
		};

	//case "Script.Member":
	//case "Script.Stage":
        //case "Script.Select":
	//case "Script.Subscript":
	default:
		writeln("???");
		return delegate JSONValue ( JSONValue val) {
			return JSONValue("not yet implemented");
		};
	}
}

void main(char[][] args)
{
	if (args.length < 2) {
		writefln("Usage: %s expression < json_input", args[0]);
		return;
	}

	auto scriptText = args[1].to!string;
	auto parseTree = Script(scriptText);
	auto program = compile(parseTree);

	auto input = parseJSON(stdin.byChunk(1024).joiner);
	JSONValue[] inputArr;
	if (input.type == JSON_TYPE.ARRAY)
		inputArr = input.array;
	else
		inputArr = [input];

	auto output = map!program(input);
	writeln(toJSON(&output));
}
