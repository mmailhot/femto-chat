module femtochat.app;

import std.stdio;
import std.concurrency;
import femtochat.connection;
import femtochat.messages;
import core.thread;

void main(string[] args)
{
  if(args.length != 4){
    writeln("Program must be called with 3 args, server url, channel and nick.");
  }else{
    Tid connTid = spawn(&spawnConnection, thisTid, args[1], cast(ushort)6667, args[2], args[3]);
    writeln("Waiting");
    Thread.sleep( dur!"seconds"(5) );
    writeln("Killing");
    send(connTid, MSG_KILL());
  }
}
