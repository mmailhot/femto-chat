module femtochat.connection;

import std.stdio;
import std.concurrency;
import std.string;
import vibe.d: connectTCP, readLine;
import core.time : dur;
import femtochat.messages;

struct TCPMessage{
  string msg;
}

// An active IRC connection, and associated data
class Connection(){
  Tid tcpTid;
  Tid ownerTid;

  string channel_to_join;

}

void spawnTCP(Tid ownerTid, string url, ushort port){
  auto connection = connectTCP(url, port);
  bool killFlag = false;
  char[1024] buffer;

  while(!killFlag){
    if(connection.leastSize > 0){
      string line = cast(immutable)(connection.readLine().assumeUTF).dup;
      send(ownerTid, line);
    }
    receiveTimeout(dur!"msecs"(50),
                   (string s) { writeln("Received a string"); },
                   (MSG_KILL m) {
                     connection.close();
                     killFlag = true;
                   });
  }
}

void spawnConnection(Tid ownerTid, string url, ushort port){
  Tid tcpTid = spawn(&spawnTCP, thisTid, url, port);
  bool killFlag = false;

  while(!killFlag){
    receive((string s) { writeln(s); },
            (MSG_KILL m) {
              send(tcpTid, m);
              killFlag = true;
            });
  }
}
