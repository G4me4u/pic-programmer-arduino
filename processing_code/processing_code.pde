import processing.serial.*;

Serial myPort;  // The serial port

void setup() {
  // List all the available serial ports
  printArray(Serial.list());
  // Open the port you are using at the rate you want:
  myPort = new Serial(this, Serial.list()[1], 9600);
  
  delay(2000);
  
  myPort.write('b');
  feedback();
  feedback();
  feedback();
  myPort.write('e');
  feedback();
  myPort.write('z');
  feedback();
  myPort.write('l');
  myPort.write(0x00);
  myPort.write(0x04);
  feedback();
  myPort.write('w');
  feedback();
  myPort.write('r');
  feedback();
  feedback();
  myPort.write('s');
  feedback();
}

void feedback() {
  String r = "";
  while (true) {
    // Wait for input
    while(myPort.available() == 0)
      delay(1);
    int byteIn = myPort.read();
    if (byteIn == 10) // new line
      break;
    r += (char)byteIn;
  }
  println(r);
}