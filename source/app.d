module femtochat.app;

import std.stdio;
import std.concurrency;
import femtochat.connection;
import femtochat.messages;
import core.thread;

void main()
{
  Tid connTid = spawn(&spawnConnection, thisTid, "irc.synirc.net", cast(ushort)6667);
  writeln("Waiting");
  Thread.sleep( dur!"seconds"(5) );
  writeln("Killing");
  send(connTid, MSG_KILL());
}
