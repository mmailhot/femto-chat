module femtochat.app;

import std.stdio;
import vibe.d;
import femtochat.connection;
import femtochat.messages;
import core.thread;
import core.runtime;

shared static this() {
  runTask({ mainTask(Runtime.args); });
}

void mainTask(string[] args)
{
  if(args.length != 4){
    writeln("Program must be called with 3 args, server url, channel and nick.");
  }else{
    Task connTid = runTask({
        spawnConnection(thisTid, args[1], cast(ushort)6667, args[2], args[3]);
      });
  }
}
