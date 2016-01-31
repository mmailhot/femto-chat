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

  bool inChannel = false;

  this(TCPConnection tcpConnection, string channel, string nick){
    this.tcpConnection = tcpConnection;
    this.channel_name = channel;
    this.nick = nick;
  }

  void send(T)(T msg){
    this.tcpConnection.write(ircSerialize(msg));
  }

  void connectToServer(){
    send(IrcNick(this.nick));
    send(IrcUser(this.nick));
  }

  void joinChannel(){
    if(this.inChannel) return;
    send(IrcJoin(format("#%s", this.channel_name)));
    this.inChannel = true;
  }

  void respondToPing(string identifier){
    send(IrcPong(identifier));
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
  conn.connectToServer();

  while(!killFlag){
    yield();
    receiveTimeout(dur!"msecs"(50),
                   (IrcPing m){conn.respondToPing(m.identifier);},
                   (IrcNotice m){writeln(m.msg);},
                   (IrcMotd m){writeln(m.msg);},
                   (IrcMode m){conn.joinChannel();},
                   (Variant v){writeln(v);}
                   );
  }
}
