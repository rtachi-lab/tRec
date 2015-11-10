import java.awt.Button;
import java.awt.TextField;
import java.awt.Label;
import java.awt.Choice;
import java.awt.Color;
import java.awt.event.ActionListener;
import java.awt.event.ActionEvent;
import java.awt.event.ItemListener;
import java.awt.event.ItemEvent;
import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.File;
import javax.sound.sampled.TargetDataLine;
import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.Mixer;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioFileFormat;
import java.util.Arrays;
import java.nio.charset.Charset;
import java.util.Date;
import java.util.Calendar;

// default setting ---------------------
String outpath = System.getProperty("user.dir");
String prefix = "test";
int sylmin = 10;
int gapmin = 5;
int sylmax = 300;
int gapmax = 300;
int thresh = -45;
int sylnum = 8;
int targetdevice = 0;
// ----------------------------------

// GUI
int gW = 345;
int gH = 210;
int pX = 100;
int pY = 55;
int pW = 240;
int pH = 150;
int bgcolor = 222;

// globals
TargetDataLine target;
RecordingBuffer recbuff;
Recording record;
AudioFormat format;
Mixer.Info[] mixerInfoList;
boolean startFlag = false;
boolean flgRefresh = false;
int prevtime = 0;

//// fundamental settings
int sampleRate = 32000;
int bitResolution = 16;
int transBufferSize = 512;
int maxRecordDuration = 30;
int drawDurtaion = 2;

// GUI controls
Button    btnPath,btnStart,btnDevice,btnSet;
TextField txfPrefix,txfSylmin,txfSylmax,txfGapmin,txfGapmax,txfCount,txfThresh,txfPath;
Label     lblPrefix,lblSyl,lblSylmax,lblGap,lblGapmax,lblCount,lblThresh,lblPath,lblDevice;
Choice    chcDevice;

String[] item;

// -------------------------------------------
void setup() {
//  println(System.getProperty("user.dir"));
//  try {
//    println(new File(".").getCanonicalPath());
//  } catch(Exception e){};
  
  // window
  size(gW, gH);
  frameRate(30);
  background(bgcolor);
  fill(0); 
  rect(pX,pY,pW,pH);
  setLayout(null);
 
  // デバイス名
  mixerInfoList = AudioSystem.getMixerInfo();
  item = new String[mixerInfoList.length];
  for( int i=0; i<mixerInfoList.length; i++) {
    String name = mixerInfoList[i].getName();
    byte[] b = name.getBytes(Charset.forName("ISO-8859-1"));
    String strtemp = new String(b,Charset.forName("Windows-31j"));
    item[i] = str(i) +": " + strtemp;
    println(item[i] + ": " + mixerInfoList[i].getDescription());
  }
  // Audio format
  format = new AudioFormat((float)sampleRate,bitResolution,2,true,true);
  
  // GUI setting
  setGUI();
}

// -------------------------------------------
void draw() {
  // background
  background(bgcolor);
  fill(0); stroke(0);
  rect(pX,pY,pW,pH);

  if(startFlag==true) {
    // data fetch
    float[]wave = recbuff.getWave();
    float[]env = recbuff.getEnv();
    int wp = recbuff.getWavePointer();
    int ep = recbuff.getEnvPointer();
    int wdrawsize = drawDurtaion*sampleRate;
    int edrawsize = drawDurtaion*1000;
    int wavesize = wave.length;
    int envsize = env.length;
    int syl = recbuff.getSyl();
    int gap = recbuff.getGap();
    int elm = recbuff.getElm();
    noFill();
    stroke(255);
    // waveform
    beginShape();
    for ( int i = 0; i < wdrawsize; i++ ) {
      vertex( pX+1+i*pW/wdrawsize, pY+pH/2-wave[(wp+i+(wavesize-wdrawsize))%wavesize]*200);      
    }
    endShape();
    // envelope
    stroke(255,255,0);
    beginShape();
    for ( int i = 0; i < edrawsize; i++ ) {
      vertex( pX+1+i*pW/edrawsize, pY+pH/2-(env[(ep+i+(envsize-edrawsize))%envsize]));      
    }
    endShape();
    // threshold
    stroke(0,255,0);
    line( pX, pY+pH/2-thresh, pX+pW, pY+pH/2-thresh );
    // text
    textSize(14);
    fill(96,96,255);
    text(str(syl),pX+5,pY+19);
    text(str(gap),pX+5,pY+32);
    fill(255,0,0);
    text(str(elm),pX+5,pY+45);
    fill(0,255,0);
    if(recbuff.getElm()>=sylnum) {
      fill(255,0,0);
      stroke(255);
      ellipse(pX+pW-15,pY+15,20,20);
    }
    // limitation
    fill(bgcolor); noStroke();
    rect(pX,0,gW-pX,pY);
    rect(pX,pY+pH,gW-pX,gW-pY-pH);
    // refresh every hour
    if( flgRefresh == true && elm == 0 ) {
      refresh();
      flgRefresh = false;
    }
  }
  // for refresh
  if( prevtime==59 && minute() == 0 ) flgRefresh = true;
  prevtime = minute();
}

// ------------------------------------------
void keyPressed() {
  if (key == 's') startFlag = false;
  if (key == 'b') startFlag = true;
}

// ------------------------------------------
boolean startAudio() {
  // set parameters
  prefix = txfPrefix.getText();
  sylmin = int(txfSylmin.getText());
  sylmax = int(txfSylmax.getText());
  gapmin = int(txfGapmin.getText());    
  gapmax = int(txfGapmax.getText());
  sylnum = int(txfCount.getText());
  thresh = int(txfThresh.getText());
  // audio
  try {
    target = AudioSystem.getTargetDataLine(format,mixerInfoList[targetdevice]);
    target.open( format );
    target.start();
  } catch(Exception e) { 
    println(e);
    return false;
  }
  recbuff = new RecordingBuffer();
  record = new Recording(recbuff,format);
  recbuff.start();
  record.start();
  println("start");
  return true;
}

// ------------------------------------------
void haltAudio() {
  // quit
  record.quit();
  recbuff.quit();    
  try {
    target.close();
  } catch(Exception e) { println(e); }
  println("stop");
}  

// -------------------------------------------
void refresh() {
  // quit
  haltAudio();
  startAudio();
  // set parameter
  println("refreshed "+nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2));
}

// ----------------------------------------
void folderSelected(File selection) {
  if (selection == null) {
    println("cancelled");
  } else {
    String s = selection.getAbsolutePath();
    outpath = s;
    println("New directory  " + s);
    txfPath.setText(outpath);
  }
}

// -----------------------------------------
void setGUI() {
  lblDevice = new Label("input");
  lblDevice.setBounds(5,5,35,20);
  chcDevice = new Choice();
  chcDevice.setBounds(40,5,300,20);
  lblPath = new Label("path");
  lblPath.setBounds(5,30,35,20);
  txfPath = new TextField();
  txfPath.setBounds(40,30,275,20);
  btnPath = new Button("...");
  btnPath.setBounds(320,30,20,20);
  lblPrefix = new Label("prefix");
  lblPrefix.setBounds(5,55,40,20);
  txfPrefix = new TextField();
  txfPrefix.setBounds(40,55,55,20);
  lblSyl = new Label("syl");
  lblSyl.setBounds(5,80,30,20);
  txfSylmin = new TextField();
  txfSylmin.setBounds(35,80,30,20);
  txfSylmax = new TextField();
  txfSylmax.setBounds(65,80,30,20);
  lblGap = new Label("gap");
  lblGap.setBounds(5,105,30,20);
  txfGapmin = new TextField();
  txfGapmin.setBounds(35,105,30,20);
  txfGapmax = new TextField();
  txfGapmax.setBounds(65,105,30,20);
  lblCount = new Label("syl count");
  lblCount.setBounds(5,130,60,20);
  txfCount = new TextField();
  txfCount.setBounds(65,130,30,20);
  lblThresh = new Label("threshold");
  lblThresh.setBounds(5,155,60,20);
  txfThresh = new TextField();
  txfThresh.setBounds(65,155,30,20);
  btnSet = new Button("Set");
  btnSet.setBounds(5,180,35,25);
  btnStart = new Button("Start");
  btnStart.setBounds(42,180,53,25);

  // default value setting
  txfPath.setText(outpath);
  txfPrefix.setText(prefix);
  txfSylmin.setText(str(sylmin));
  txfSylmax.setText(str(sylmax));
  txfGapmin.setText(str(gapmin));
  txfGapmax.setText(str(gapmax));
  txfCount.setText(str(sylnum));
  txfThresh.setText(str(thresh));

  // choice item
  for(int i=0; i<item.length; i++) {
    chcDevice.add(item[i]);
  }
  chcDevice.select(targetdevice);
  
  // listeners
  btnPath.addActionListener(new BottonActionListener(0));
  btnSet.addActionListener(new BottonActionListener(1));
  btnStart.addActionListener(new BottonActionListener(2));
  chcDevice.addItemListener(new ChoiceItemListener());

  // add
  add(btnPath);
  add(btnSet);
  add(btnStart);
  add(txfPrefix);
  add(txfSylmin);
  add(txfSylmax);
  add(txfGapmin);
  add(txfGapmax);
  add(txfCount);
  add(txfThresh);
  add(txfPath);
  add(lblPrefix);
  add(lblSyl);
  add(lblGap);
  add(lblCount);
  add(lblThresh);
  add(lblPath);
  add(lblDevice);
  add(chcDevice);
}
// ------------------------------------------------
class BottonActionListener implements ActionListener {
  private int btnid;
  BottonActionListener(int id) { btnid = id; }
  public void actionPerformed(ActionEvent e) {
    // path button
    if(btnid==0) {
      println("test");
      File folderToStartFrom = new File( outpath );
      selectFolder("Select a folder to process:", "folderSelected", folderToStartFrom );
    }
    // set button
    if(btnid==1) {
      // set parameters
      prefix = txfPrefix.getText();
      sylmin = int(txfSylmin.getText());
      sylmax = int(txfSylmax.getText());
      gapmin = int(txfGapmin.getText());    
      gapmax = int(txfGapmax.getText());
      sylnum = int(txfCount.getText());
      thresh = int(txfThresh.getText());
    }

    // start button
    if(btnid==2) {
      if(startFlag==false) {
        boolean okflg = startAudio();
        if(okflg == true) { 
          startFlag = true;
          btnStart.setLabel("Stop");
          btnStart.setForeground(Color.red);
        }
      } else {
        // Halt audio
        haltAudio();
        startFlag = false;
        btnStart.setLabel("Start");
        btnStart.setForeground(Color.black);
      }
    }
    
  }
}

class ChoiceItemListener implements ItemListener  {
  void itemStateChanged(ItemEvent e) {
    targetdevice = chcDevice.getSelectedIndex();
    println("selected:" + item[targetdevice]);
  }
}

