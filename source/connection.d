module femtochat.connection;

import std.stdio;
import std.concurrency;
import std.string;
import std.format;
import std.variant;
import vibe.d: connectTCP, readLine;
import core.time : dur;
import femtochat.messages;

struct TCPMessage{
  string msg;
}

// An active IRC connection, and associated data
class Connection{
  Tid tcpTid;
  Tid ownerTid;

  string channel_name;
  string nick;

  this(Tid ownerTid, Tid tcpTid, string channel, string nick){
    this.ownerTid = ownerTid;
    this.tcpTid = tcpTid;
    this.channel_name = channel;
    this.nick = nick;
  }

  void connectToChannel(){
    send(tcpTid, format("NICK %s", this.nick));
    send(tcpTid, format("USER %s 0 * %s", this.nick, this.nick));
    send(tcpTid, format("JOIN %s", this.channel_name));
  }
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
                   (string s) {connection.write(s ~ "\n");},
                   (MSG_KILL m) {
                     connection.close();
                     killFlag = true;
                   });
  }
}

void spawnConnection(Tid ownerTid, string url, ushort port, string channel, string nick){
  Tid tcpTid = spawn(&spawnTCP, thisTid, url, port);
  bool killFlag = false;

  Connection conn = new Connection(ownerTid, tcpTid, channel, nick);
  conn.connectToChannel();

  while(!killFlag){
    receive((string s) { writeln(s); },
            (MSG_KILL m) {
              writeln("KILLING");
              send(tcpTid, m);
              writeln("KILLING");
              killFlag = true;
            });
  }
}
