
class Color:
  static RED    ::= [255, 0, 0]
  static GREEN  ::= [0, 255, 0]
  static BLUE   ::= [0, 0, 255]
  static WHITE  ::= [255, 255, 255]
  static PINK   ::= [255, 0, 255]
  static LILA   ::= [125, 68, 255]
  static CYAN   ::= [0, 255, 255]
  static YELLOW ::= [255, 200, 0]
  static OFF    ::= [0, 0, 0]

  color := ?

  constructor .color:

  constructor.red .color=RED:
  
  constructor.green .color=GREEN:

  constructor.blue .color=BLUE:

  constructor.white .color=WHITE:

  constructor.pink .color=PINK:

  constructor.lila .color=LILA: 

  constructor.cyan .color=CYAN:

  constructor.yellow .color=YELLOW:

  constructor.off .color=OFF:

  serialize -> List:
    return color