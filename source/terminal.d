module femtochat.terminal;

import nc = deimos.ncurses.ncurses;
import std.typecons;
import std.string : toStringz, format;
import std.algorithm : remove, min;
import std.conv;
import std.array;
import vibe.d;

struct SendMessage {
  string text;
}

struct DisplayableMessage {
  string nick = "";
  short color = 2;

  string message;
  
  this(string msg){
    this.message = msg;
  }

  this(string nick, short color, string message){
    this.nick = nick;
    this.color = color;
    this.message = message;
  }

}

class Terminal{
  nc.WINDOW* messagesDisplay;
  nc.WINDOW* inputDisplay;
  int width;
  int height;
  DisplayableMessage[] messages;

  this(){
    nc.initscr();
    nc.noecho();
    nc.cbreak();
    nc.timeout(50);
    // nc.start_color();
    nc.refresh();
    nc.nonl();

    nc.init_pair(1, nc.COLOR_WHITE, nc.COLOR_BLACK);
    nc.init_pair(2, nc.COLOR_GREEN, nc.COLOR_BLACK);

    this.width = nc.COLS;
    this.height = nc.LINES;
    this.messagesDisplay = nc.newwin(this.height - 3, this.width, 0, 0);
    this.inputDisplay = nc.newwin(3, this.width, this.height - 3, 0);
    nc.scrollok(this.messagesDisplay, true);
    nc.box(this.messagesDisplay, 0, 0);
    nc.box(this.inputDisplay, 0, 0);
    nc.wrefresh(this.messagesDisplay);
    nc.wrefresh(this.inputDisplay);
  }

  ~this(){
    nc.delwin(inputDisplay);
    nc.delwin(messagesDisplay);
    nc.endwin();
  }

  Tuple!(int, "y", int, "x") getCoords(){
    int x;
    int y;
    nc.getyx(this.messagesDisplay, y, x);
    return tuple!("y", "x")(y, x);
  }

  void updateInputField(string s){
    nc.werase(this.inputDisplay);
    nc.box(this.inputDisplay, 0, 0);

    nc.mvwprintw(this.inputDisplay, 1, 1, toStringz(s));

    nc.wrefresh(this.inputDisplay);
  }

  void drawMessages(){
    nc.werase(this.messagesDisplay);
    nc.box(this.messagesDisplay, 0, 0);
    foreach(int i, DisplayableMessage msg; this.messages){
      int msgOffset = 1;
      if(msg.nick.length > 0){
        msgOffset += msg.nick.length + 2;
        nc.wattron(this.messagesDisplay, nc.COLOR_PAIR(msg.color));
        nc.mvwprintw(this.messagesDisplay, 1 + i, 1, toStringz(msg.nick ~ ":"));
        nc.wattroff(this.messagesDisplay, nc.COLOR_PAIR(msg.color));
      }
      nc.wattron(this.messagesDisplay, nc.COLOR_PAIR(1));
      nc.mvwprintw(this.messagesDisplay, 1 + i, msgOffset, toStringz(msg.message));
      nc.wattroff(this.messagesDisplay, nc.COLOR_PAIR(1));
    }
    nc.wrefresh(this.messagesDisplay);
  }

  void newMessage(DisplayableMessage msg){
    auto coords = getCoords();
    string text = msg.message;

    if(msg.nick.length > 0){
      text = "[" ~ msg.nick ~"]: " ~ msg.message;
    }

    string[] lines = breakText(text);

    foreach(i; 0..lines.length){
      nc.wscrl(this.messagesDisplay, 1);
      nc.wmove(this.messagesDisplay, this.height - 5, 1);
      nc.wclrtoeol(this.messagesDisplay);
    }
    nc.box(this.messagesDisplay, 0, 0);
    foreach(int i, string line; lines){
      nc.mvwprintw(this.messagesDisplay, this.height - 4 - to!int(lines.length) + i, 1, toStringz(line));
    }
    nc.wmove(this.messagesDisplay, coords.y, coords.x);
    nc.wrefresh(this.messagesDisplay);

  }

  private string[] breakText(string text){
    string[] result;

    for(int i = 0; i < text.length; i += (this.width - 2)){
      result ~= text[i..min(text.length, (i + this.width - 2))];
    }

    return result;
  }
}

void launchInputTask(Task ownerTid, Terminal t){
  runTask({
      string input = "";
      t.updateInputField(input);
      while(true){
        yield();
        auto c = nc.getch();
        if(c == nc.KEY_BACKSPACE || c == 127){ // BACKSPACE
          if(input.length > 0){
            input = input[0..$-1];
            t.updateInputField(input);
          }
        }else if(c == nc.KEY_ENTER || c == 10 || c == 13){
          send(ownerTid, SendMessage(input));
          input = "";
          t.updateInputField(input);
        }else if(c >= 32 && c <= 126){
          input ~= c;
          t.updateInputField(input);
        }
      }
  });
}
