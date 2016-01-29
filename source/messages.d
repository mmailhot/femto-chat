module femtochat.messages;

import std.traits;
import std.typetuple;
import std.stdio;
import std.conv;
import std.string;

import vibe.d;

enum NoSerialize;
enum LongString;

template ID(alias x){alias x ID;}

string ircSerialize(T)(T msg){
  alias TU = Unqual!T;

  static assert(is(TU == struct));

  alias FIELD_TYPES = FieldNameTuple!TU;

  string serializedMsg = msg.TAG ~ " ";

  foreach(f; FIELD_TYPES){
    enum longStringIndex = staticIndexOf!(LongString, __traits(getAttributes, __traits(getMember, msg, f)));
    enum noSerializeIndex = staticIndexOf!(NoSerialize, __traits(getAttributes, __traits(getMember, msg, f)));

    static if(longStringIndex != -1){
      serializedMsg  ~= ":" ~ __traits(getMember, msg, f);
    }else static if(noSerializeIndex == -1){
      serializedMsg ~= to!string(__traits(getMember, msg, f)) ~ " ";
    }
  }

  serializedMsg ~= "\n";

  return serializedMsg;
}

void ircDeserializeAndSend(string s, Task recipient){
  writeln(s);
  string[] words = s.split();

  foreach(m; __traits(allMembers, femtochat.messages)){
    static if(is(ID!(__traits(getMember, femtochat.messages, m)))){
      alias TU = Unqual!((__traits(getMember, femtochat.messages, m)));
      
      static if(is(TU == struct) && __traits(hasMember, TU, "TAG")){
        alias FIELD_TYPES = FieldNameTuple!TU;
        
        int i = 0;
        if(TU.TAG == words[1]){
          TU msg;
          foreach(f; FIELD_TYPES){
            enum longStringIndex = staticIndexOf!(LongString, __traits(getAttributes, __traits(getMember, msg, f)));
            
            static if(longStringIndex != -1){
              __traits(getMember, msg, f) = join(words[i..$], " ")[1..$];
            }else{
              __traits(getMember, msg, f) = to!(typeof(ID!(__traits(getMember, msg, f))))(words[i]);
            }
            
            i++;
            if(i == 1){
              i++;
            }
          }
          writeln(msg);
          send(recipient, msg);
        }
      }
    }
  }
}

unittest{
  struct TestStruct1{
    enum TAG = "FOO";

    string a;
    @NoSerialize string b;
    int c;
    short d;
    @LongString string e;
  }

  assert(ircSerialize(TestStruct1("test", "shouldntseethis", 23, 2, "A Very Long String")) == "FOO test 23 2 :A Very Long String\n");
}

struct IrcNick{
  enum TAG = "NICK";

  string nick;
}

struct IrcUser{
  enum TAG = "USER";

  this(string nick){
    this.username = nick;
    this.name = nick;
  }

  string username;

  int mode = 0;
  string somethingRequired = "*";

  string name;
}

struct IrcJoin{
  enum TAG = "JOIN";

  string channel_name;
}

struct IrcNotice{
  @NoSerialize string sender;

  enum TAG = "NOTICE";

  string type;
  @LongString string msg;
}
