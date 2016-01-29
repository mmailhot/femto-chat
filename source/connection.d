module femtochat.connection;

import std.stdio;
import std.string;
import std.format;
import std.variant;
import std.functional : toDelegate;
import vibe.d;
import vibe.core.concurrency;
import core.time : dur;
import femtochat.messages;

struct TCPMessage{
  string msg;
}

// An active IRC connection, and associated data
class Connection{
  TCPConnection tcpConnection;

  string channel_name;
  string nick;

  this(TCPConnection tcpConnection, string channel, string nick){
    this.tcpConnection = tcpConnection;
    this.channel_name = channel;
    this.nick = nick;
  }

  void send(T)(T msg){
    this.tcpConnection.write(ircSerialize(msg));
  }

  void connectToChannel(){
    send(IrcNick(this.nick));
    send(IrcUser(this.nick));
    send(IrcJoin(this.channel_name));
  }
}

void spawnTCPReader(Task ownerTid, TCPConnection connection){
  while(connection.connected){
    yield();
    if(connection.leastSize > 0){
      string line = cast(immutable)(connection.readLine().assumeUTF).dup;
      ircDeserializeAndSend(line, ownerTid);
    }
  }
}

void spawnConnection(Task ownerTid, string url, ushort port, string channel, string nick){
  Task myTid = thisTid();
  bool killFlag = false;

  TCPConnection connection = connectTCP(url, port);
  runTask(toDelegate(&spawnTCPReader), thisTid, connection);
  sleep(500.msecs);
  Connection conn = new Connection(connection, channel, nick);
  conn.connectToChannel();

  while(!killFlag){
    yield();
    receiveTimeout(dur!"msecs"(50),
                   (Variant v){writeln("FOO");}
                   );
  }
}
