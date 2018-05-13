import processing.serial.*;

Serial myPort;  // The serial port

void setup() {
  // List all the available serial ports
  printArray(Serial.list());
  // Open the port you are using at the rate you want:
  myPort = new Serial(this, Serial.list()[0], 9600);
  
  delay(2000);
  
  doCommand((byte)'b');
  feedback();
  feedback();
  doCommand((byte)'z');
  doCommand((byte)'e');
  
  writeProgramWord(0x0328);
  writeProgramWord(0x0034);
  writeProgramWord(0x0034);
  writeProgramWord(0x2100);
  writeProgramWord(0x0C11);
  writeProgramWord(0x2000);
  writeProgramWord(0x0C15);
  writeProgramWord(0x0528);
  
  doCommand((byte)'s');
  feedback();
}

void writeProgramWord(int data) {
  doCommand((byte)'w');
  doDataCommand((byte)'p', data);
  doCommand((byte)'i');
}

void doCommand(byte command) {
  myPort.write(command);
  feedback();
}

void doDataCommand(byte command, int data) {
  myPort.write(command);
  myPort.write((data >> 0) & 0xFF);
  myPort.write((data >> 8) & 0xFF);
  feedback();
}

void feedback() {
  String r = "";
  while (true) {
    while(myPort.available() == 0)
      delay(1);
    
    int byteIn = myPort.read();
    char c = (char)byteIn;
    if (c == '\n') // new line
      break;
    r += c;
  }
  println(r);
}
