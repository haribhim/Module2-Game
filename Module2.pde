/********* VARIABLES *********/

// We control which screen is active by settings / updating
// gameScreen variable. We display the correct screen according
// to the value of this variable.
//
// 0: Initial Screen
// 1: Game Screen
// 2: Game-over Screen

// Serial communication for ESP32 connection
import processing.serial.*;

Serial myPort;  // Create object from Serial class
String val;      // Data received from the serial port

int canvasSize = 500;
int analogMax = 4095;

// Adding in joystick input
// The commented values are different joystick Y values tried through the iterative process
float joystickX = 250;  // Initial X position (centered)
float joystickY = 30;
//float joystickY = height - 20;
//float joystickY = 250;  // Initial Y position (not needed for vertical movement here)
float prevJoystickY = 0;  // Initialize this at the start of your code

// Initialize RGB values for the ball
// These will be reset using potentiometer input
float redVal = 20;
float greenVal = 40;
float blueVal = 60;

// Game screen indicates whether the user is playing the game or waiting to start/restart
int gameScreen = 0;

// gameplay settings
float gravity = .3;
float airfriction = 0.00001;
float friction = 0.1;

// scoring
int score = 0;
int maxHealth = 100;
float health = 100;
float healthDecrease = 1;
int healthBarWidth = 60;

// ball settings
float ballX, ballY;
float ballSpeedVert = 0;
float ballSpeedHorizon = 0;
float ballSize = 20;
color ballColor = color(0);

// racket settings
color racketColor = color(0);
float racketWidth = 100;
float racketHeight = 10;

// wall settings
int wallSpeed = 5;
int wallInterval = 1000;
float lastAddTime = 0;
int minGapHeight = 200; // Can adjust the min/max gap heights to change difficulty of obstacles
int maxGapHeight = 300;  // Played around with these values in the design process
int wallWidth = 30; // Can adjust wall width to make obstacles smaller/bigger (easier/harder game)
color wallColors = color(44, 62, 80);
// This arraylist stores data of the gaps between the walls. Actuals walls are drawn accordingly.
// [gapWallX, gapWallY, gapWallWidth, gapWallHeight, scored]
ArrayList<int[]> walls = new ArrayList<int[]>();

/********* SETUP BLOCK *********/

void setup() {
  size(500, 500);
  // set the initial coordinates of the ball
  ballX=width/4;
  ballY=height/5;

  printArray(Serial.list());
  String portName = Serial.list()[6];
  println(portName);
  myPort = new Serial(this, portName, 9600); // ensure baudrate is consistent with arduino sketch

  smooth();
}


/********* DRAW BLOCK *********/

void draw() {
  // Display the contents of the current screen
  //print("game screen: ", gameScreen);
  if (gameScreen == 0) {
    initScreen();
    checkForStart();
  } else if (gameScreen == 1) {
    gameScreen();
  } else if (gameScreen == 2) {
    gameOverScreen();
    checkForRestart();
  }
}


/********* SCREEN CONTENTS *********/

void initScreen() {
  // Initial screen where we ask the user if they want to set the color using potentiometer & start the game using the button
  //print("in initScreen");
  textAlign(CENTER);
  fill(52, 73, 94);
  textSize(50);
  text("Flappy Pong", width/2, height/2);
  textSize(20);
  text("Turn the dial to set your player color", width/2, height/2+60);
  text("Then, press the button to start!", width/2, height/2+100);
}

void gameScreen() {
  background(236, 240, 241);
  readJoystickInput();
  drawRacket();
  watchRacketBounce();
  drawBall();
  applyGravity();
  applyHorizontalSpeed();
  keepInScreen();
  drawHealthBar();
  printScore();
  wallAdder();
  wallHandler();
}

void gameOverScreen() {
  background(44, 62, 80);
  textAlign(CENTER);
  fill(236, 240, 241);
  textSize(15);
  text("Your Score", width/2, height/2 - 120);
  textSize(100);
  text(score, width/2, height/2);
  textSize(20);
  text("Turn the dial to reset your player color", width/2, height/2+60);
  text("Press button to restart!", width/2, height/2+100);
}


/********* INPUTS *********/

void checkForStart() {
  if (myPort.available() > 0) {
    String val = myPort.readStringUntil('\n');
    val = trim(val);
    if (val != null) {
      int[] esp_inputs = int(split(val, ','));
      if (esp_inputs.length == 5 && esp_inputs[3] == 0) { // Checks if button is pressed
        int potVal = esp_inputs[4];
        /*
        // Initial attempt to map RGB values but I realized that if all the values are the same it's in grayscale! oops
        redVal = map(float(esp_inputs[4]), 0, 4095, 0, 255); // Map potentiometer value to 0-255 RGB color range
         greenVal = map(float(esp_inputs[4]), 0, 4095, 0, 255);
         blueVal = map(float(esp_inputs[4]), 0, 4095, 0, 255);
         */
         // Maps first 1/3 of potentiometer range to red, second third to green, last to blue
        if (potVal <= 1365) {
          // Scale for Red channel (from 0 to 1365 maps to R 0-255)
          redVal = int(map(potVal, 0, 1365, 50, 255));
          greenVal = 0;
          blueVal = 0;
        } else if (potVal <= 2730) {
          redVal = 0;
          greenVal = int(map(potVal, 1366, 2730, 50, 255));
          blueVal = 0;
        } else {
          redVal = 0;
          greenVal = 0;
          blueVal = int(map(potVal, 2731, 4095, 50, 255));
        }
        //println("R: ", redVal, ", G: ", greenVal, ", B: ", blueVal);
        startGame();
      }
    }
  }
}

void checkForRestart() {
  if (myPort.available() > 0) {
    String val = myPort.readStringUntil('\n');
    val = trim(val);
    if (val != null) {
      int[] esp_inputs = int(split(val, ','));
      if (esp_inputs.length == 5 && esp_inputs[3] == 0) {
        int potVal = esp_inputs[4];
        /*
        redVal = map(float(esp_inputs[4]), 0, 4095, 0, 255); // Map potentiometer value to 0-255 RGB color range
         greenVal = map(float(esp_inputs[4]), 0, 4095, 0, 255);
         blueVal = map(float(esp_inputs[4]), 0, 4095, 0, 255);
         */
        if (potVal <= 1365) {
          // Scale for Red channel (from 0 to 1365 maps to R 0-255)
          redVal = int(map(potVal, 0, 1365, 50, 255));
          greenVal = 0;
          blueVal = 0;
        } else if (potVal <= 2730) {
          // Scale for Green channel (from 1366 to 2730 maps to G 0-255)
          redVal = 0;
          greenVal = int(map(potVal, 1366, 2730, 50, 255));
          blueVal = 0;
        } else {
          // Scale for Blue channel (from 2731 to 4095 maps to B 0-255)
          redVal = 0;
          greenVal = 0;
          blueVal = int(map(potVal, 2731, 4095, 50, 255));
        }
        println("R: ", redVal, ", G: ", greenVal, ", B: ", blueVal);
        restart();
      }
    }
  }
}

void readJoystickInput() {
  if (myPort.available() > 0) {
    String val = myPort.readStringUntil('\n');
    val = trim(val);
    if (val != null) {
      int[] esp_inputs = int(split(val, ','));
      if (esp_inputs.length == 5) {
        joystickX = map(float(esp_inputs[0]), 0, 1023, 0, width); // Map joystick X axis to screen width
        //joystickY = map(float(esp_inputs[1]), 0, 1023, 0, width); // Y axis can be used if it works
        //println(joystickX);
        //println(joystickY);
      }
    }
  }
}


/********* OTHER FUNCTIONS *********/

// This method sets the necessery variables to start the game
void startGame() {
  gameScreen=1;
}
void gameOver() {
  gameScreen=2;
}

void restart() {
  score = 0;
  health = maxHealth;
  ballX=width/4;
  ballY=height/5;
  lastAddTime = 0;
  walls.clear();
  gameScreen = 1;
}

void drawBall() {
  // Fill color of ball based on potentiometer input
  fill(redVal, greenVal, blueVal);
  // println("drawing ball with rgb");
  ellipse(ballX, ballY, ballSize, ballSize);
}
void drawRacket() {
  // Apply the scaling factor to smooth the joystick movement
  joystickX = constrain(joystickX, racketWidth / 2, width - racketWidth / 2);
  //joystickY = constrain(joystickY, 20, height - 20);  // Bound the racket's Y movement
  // joystickX * movementScalingFactor
  fill(racketColor);
  rectMode(CENTER);
  //rect(joystickX, joystickY, racketWidth, racketHeight, 5);
  rect(joystickX, height - 20, racketWidth, racketHeight, 5);
}

// Minimal edits to the rest of this code that the initial author made for the obstacle and health elements
void wallAdder() {
  if (millis()-lastAddTime > wallInterval) {
    int randHeight = round(random(minGapHeight, maxGapHeight));
    int randY = round(random(0, height-randHeight));
    // {gapWallX, gapWallY, gapWallWidth, gapWallHeight, scored}
    int[] randWall = {width, randY, wallWidth, randHeight, 0};
    walls.add(randWall);
    lastAddTime = millis();
  }
}
void wallHandler() {
  for (int i = 0; i < walls.size(); i++) {
    wallRemover(i);
    wallMover(i);
    wallDrawer(i);
    watchWallCollision(i);
  }
}
void wallDrawer(int index) {
  int[] wall = walls.get(index);
  // get gap wall settings
  int gapWallX = wall[0];
  int gapWallY = wall[1];
  int gapWallWidth = wall[2];
  int gapWallHeight = wall[3];
  // draw actual walls
  rectMode(CORNER);
  noStroke();
  strokeCap(ROUND);
  fill(wallColors);
  rect(gapWallX, 0, gapWallWidth, gapWallY, 0, 0, 15, 15);
  rect(gapWallX, gapWallY+gapWallHeight, gapWallWidth, height-(gapWallY+gapWallHeight), 15, 15, 0, 0);
}
void wallMover(int index) {
  int[] wall = walls.get(index);
  wall[0] -= wallSpeed;
}
void wallRemover(int index) {
  int[] wall = walls.get(index);
  if (wall[0]+wall[2] <= 0) {
    walls.remove(index);
  }
}

void watchWallCollision(int index) {
  int[] wall = walls.get(index);
  // get gap wall settings
  int gapWallX = wall[0];
  int gapWallY = wall[1];
  int gapWallWidth = wall[2];
  int gapWallHeight = wall[3];
  int wallScored = wall[4];
  int wallTopX = gapWallX;
  int wallTopY = 0;
  int wallTopWidth = gapWallWidth;
  int wallTopHeight = gapWallY;
  int wallBottomX = gapWallX;
  int wallBottomY = gapWallY+gapWallHeight;
  int wallBottomWidth = gapWallWidth;
  int wallBottomHeight = height-(gapWallY+gapWallHeight);

  if (
    (ballX+(ballSize/2)>wallTopX) &&
    (ballX-(ballSize/2)<wallTopX+wallTopWidth) &&
    (ballY+(ballSize/2)>wallTopY) &&
    (ballY-(ballSize/2)<wallTopY+wallTopHeight)
    ) {
    decreaseHealth();
  }
  if (
    (ballX+(ballSize/2)>wallBottomX) &&
    (ballX-(ballSize/2)<wallBottomX+wallBottomWidth) &&
    (ballY+(ballSize/2)>wallBottomY) &&
    (ballY-(ballSize/2)<wallBottomY+wallBottomHeight)
    ) {
    decreaseHealth();
  }

  if (ballX > gapWallX+(gapWallWidth/2) && wallScored==0) {
    wallScored=1;
    wall[4]=1;
    score();
  }
}

void drawHealthBar() {
  noStroke();
  fill(189, 195, 199);
  rectMode(CORNER);
  rect(ballX-(healthBarWidth/2), ballY - 30, healthBarWidth, 5);
  if (health > 60) {
    fill(46, 204, 113);
  } else if (health > 30) {
    fill(230, 126, 34);
  } else {
    fill(231, 76, 60);
  }
  rectMode(CORNER);
  rect(ballX-(healthBarWidth/2), ballY - 30, healthBarWidth*(health/maxHealth), 5);
}
void decreaseHealth() {
  health -= healthDecrease;
  if (health <= 0) {
    gameOver();
  }
}
void score() {
  score++;
}
void printScore() {
  textAlign(CENTER);
  fill(0);
  textSize(30);
  text(score, height/2, 50);
}

void watchRacketBounce() {
  //float overhead = joystickY - prevJoystickY;  // Track vertical movement from joystick
  float overhead = 0;

  // Check if the ball is over the racket horizontally
  if ((ballX + (ballSize / 2) > joystickX - (racketWidth / 2)) &&
    (ballX - (ballSize / 2) < joystickX + (racketWidth / 2))) {
    // Check if the ball has collided with the racket vertically
    //if (dist(ballX, ballY, ballX, joystickY) <= (ballSize / 2) + abs(overhead)) {
    if (dist(ballX, ballY, ballX, height - 20) <= (ballSize / 2)) {
      makeBounceBottom(height - 20);
      //makeBounceBottom(joystickY);  // Use fixed Y position for racket
      ballSpeedHorizon = (ballX - joystickX) / 10;  // Use joystickX instead of mouseX

      if (overhead < 0) {
        ballY += (overhead / 2);
        ballSpeedVert += (overhead / 2);
      }
    }
  }
  //prevJoystickY = joystickY;
}

void applyGravity() {
  ballSpeedVert += gravity + 0.2;
  ballY += ballSpeedVert - 0.65;
  ballSpeedVert -= (ballSpeedVert * airfriction);
}
void applyHorizontalSpeed() {
  ballX += ballSpeedHorizon;
  ballSpeedHorizon -= (ballSpeedHorizon * airfriction);
}
// ball falls and hits the floor (or other surface)
void makeBounceBottom(float surface) {
  ballY = surface-(ballSize/2);
  ballSpeedVert*=-1;
  ballSpeedVert -= (ballSpeedVert * friction);
}
// ball rises and hits the ceiling (or other surface)
void makeBounceTop(float surface) {
  ballY = surface+(ballSize/2);
  ballSpeedVert*=-1;
  ballSpeedVert -= (ballSpeedVert * friction);
}
// ball hits object from left side
void makeBounceLeft(float surface) {
  ballX = surface+(ballSize/2);
  ballSpeedHorizon*=-1;
  ballSpeedHorizon -= (ballSpeedHorizon * friction);
}
// ball hits object from right side
void makeBounceRight(float surface) {
  ballX = surface-(ballSize/2);
  ballSpeedHorizon*=-1;
  ballSpeedHorizon -= (ballSpeedHorizon * friction);
}
// keep ball in the screen
void keepInScreen() {
  // ball hits floor
  if (ballY+(ballSize/2) > height) {
    makeBounceBottom(height);
  }
  // ball hits ceiling
  if (ballY-(ballSize/2) < 0) {
    makeBounceTop(0);
  }
  // ball hits left of the screen
  if (ballX-(ballSize/2) < 0) {
    makeBounceLeft(0);
  }
  // ball hits right of the screen
  if (ballX+(ballSize/2) > width) {
    makeBounceRight(width);
  }
}
