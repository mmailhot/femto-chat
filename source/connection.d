module femtochat.connection;

import std.stdio;
import std.string;
import std.format;
import std.variant;
import std.regex;
import std.functional : toDelegate;
import vibe.d;
import vibe.core.concurrency;
import core.time : dur;
import femtochat.messages;
import femtochat.terminal;

struct TCPMessage{
  string msg;
}

string parseUsername(string sender){
  auto r = ctRegex!(`^:([a-zA-Z0-9_\-\\\[\]\{\}]*)\!.*$`);
  auto c = matchFirst(sender, r);
  return c[1];
}

// An active IRC connection, and associated data
class Connection{
  TCPConnection tcpConnection;
  Terminal term;

  string channel_name;
  string nick;

  bool inChannel = false;

  this(TCPConnection tcpConnection, string channel, string nick, Terminal t){
    this.tcpConnection = tcpConnection;
    this.channel_name = channel;
    this.nick = nick;
    this.term = t;
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

  void receiveMessage(IrcPrivMsg msg){
    term.newMessage(DisplayableMessage(parseUsername(msg.sender), 1, msg.msg));
  }

  void sendMessage(string text){
    term.newMessage(DisplayableMessage(this.nick, 1, text));
    send(IrcPrivMsg("", "#" ~ this.channel_name, text));
  }

  void receivePlaintext(string text){
    term.newMessage(DisplayableMessage(text));
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
  Terminal t = new Terminal();
  launchInputTask(thisTid(), t);
  Connection conn = new Connection(connection, channel, nick, t);
  conn.connectToServer();
  while(!killFlag){
    yield();
    receiveTimeout(dur!"msecs"(50),
                   (IrcPing m){conn.respondToPing(m.identifier);},
                   (IrcNotice m){conn.receivePlaintext(m.msg);},
                   (IrcMotd m){conn.receivePlaintext(m.msg);},
                   (IrcMode m){conn.receivePlaintext("Connecting");
                     conn.joinChannel();},
                   (IrcPrivMsg m){conn.receiveMessage(m);},
                   (IrcChanMsg m){conn.receivePlaintext(m.msg);},
                   (SendMessage m){conn.sendMessage(m.text);},
                   (Variant v){}
                   );
  }
}
