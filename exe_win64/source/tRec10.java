import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import processing.serial.*; 
import java.awt.*; 
import java.awt.event.*; 
import java.util.Date; 
import java.util.TimeZone; 
import java.util.Calendar; 
import java.nio.charset.Charset; 
import java.io.DataInputStream; 
import java.io.ByteArrayInputStream; 
import javax.swing.JLayeredPane; 
import javax.sound.sampled.Mixer; 
import javax.sound.sampled.AudioFormat; 
import javax.sound.sampled.AudioSystem; 
import javax.sound.sampled.SourceDataLine; 
import javax.sound.sampled.TargetDataLine; 
import javax.sound.sampled.AudioFileFormat; 
import javax.sound.sampled.AudioInputStream; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class tRec10 extends PApplet {



















// global objects
AudioFormat format;
Mixer.Info[] mixerInfoList;
RTProcess rtproc;
// global variables
byte[] readBuff;
String[] inputnames;
String savepath1, prefix1, savepath2, prefix2;
int[] inputindex, vocPtrn;
int inputselected;
int sylmin1, sylmax1, gapmin1, gapmax1, threshA1, threshP1, sylnum1;
int sylmin2, sylmax2, gapmin2, gapmax2, threshA2, threshP2, sylnum2;
int prevtime, flgvpdcnt;
boolean flgStereo,flgStart, flgRefresh, flgVocalDetect;

// audio settings
//   read audio buffer every 32ms (=1024/32000)
//   windowsize = 256 (8ms)
//   timestep = 128 (4ms)
//   maximum recordable duration: 30 seconds
//   display duration: 2 seconds
//   dataline buffer is 8 times larger than transfer buffer (1024*4bytes*8)
//      this should not relate with the latancy
int sampleRate = 32000;
int bitDepth = 16;
int transBufferSize = 1024; 
int analysisWindowSize = 256;
int analysisTimeStep = 128;
//int yinParam = 100; // lower limit: 320 Hz. Must be smaller than analysisWindowSize
int yinParam = 100; // lower limit: 1000 Hz. Must be smaller than analysisWindowSize
int maxRecordDuration = 30;
int dispDuration = 2;
int datalineBufferSize = transBufferSize *4*8;
int flgvpddur = 10; // 10*16? ms
int margin = 200; // 200 ms

// display setting
int gW = 345;
int gH = 345;
int pX = 125;
int pY = 75;
int pW = 215;
int pH = 265;
int bgcolor = 240;

// -------------------------------------------
public void settings() {
    size(gW, gH);
}
public void setup() {  
  // global initialize
  flgStart = flgRefresh = flgVocalDetect = false;      
  // read initial file
  boolean rdy = false;
  BufferedReader reader = createReader("trec.ini");
  try { rdy = reader.ready(); } catch(Exception e) { println(e); }
  if (rdy){
    println("exist");
    String[] lines = new String[20];
    try { for(int i=0; i<20; i++) lines[i] = reader.readLine(); reader.close();} 
    catch(Exception e) { println(e); return; }
    inputselected = PApplet.parseInt(lines[0]);
    if (lines[1].length()==0) savepath1 = System.getProperty("user.dir");
    else savepath1 = lines[1];
    if (lines[2].length()==0) savepath2 = System.getProperty("user.dir");
    else savepath2 = lines[2];
    prefix1 = lines[3];
    sylmin1 = PApplet.parseInt(lines[4]);
    sylmax1 = PApplet.parseInt(lines[5]);
    gapmin1 = PApplet.parseInt(lines[6]);
    gapmax1 = PApplet.parseInt(lines[7]);
    threshA1 = PApplet.parseInt(lines[8]);
    threshP1 = PApplet.parseInt(lines[9]);
    sylnum1 = PApplet.parseInt(lines[10]);
    flgStereo = PApplet.parseBoolean(lines[11]);
    prefix2 = lines[12];
    sylmin2 = PApplet.parseInt(lines[13]);
    sylmax2 = PApplet.parseInt(lines[14]);
    gapmin2 = PApplet.parseInt(lines[15]);
    gapmax2 = PApplet.parseInt(lines[16]);
    threshA2 = PApplet.parseInt(lines[17]);
    threshP2 = PApplet.parseInt(lines[18]);
    sylnum2 = PApplet.parseInt(lines[19]);
  } else {
    println("noexist");
    inputselected = 0;
    savepath1 = System.getProperty("user.dir");
    savepath2 = System.getProperty("user.dir");
    prefix1 = "test";
    sylmin1 = 20;
    sylmax1 = 300;
    gapmin1 = 5;
    gapmax1 = 500;
    threshA1 = -50;
    threshP1 = 30;
    sylnum1 = 6;
    flgStereo = true;
    prefix2 = "testR";
    sylmin2 = 20;
    sylmax2 = 300;
    gapmin2 = 5;
    gapmax2 = 500;
    threshA2 = -50;
    threshP2 = 30;
    sylnum2 = 6;
  }
  // window
  frameRate(30);
  background(bgcolor);
  fill(0); 
  rect(pX,pY,pW,pH);
  strokeCap(SQUARE);
  // Audio I/O
  mixerInfoList = AudioSystem.getMixerInfo();
  inputindex = new int[0];
  inputnames = new String[0];
  for( int i=0; i<mixerInfoList.length; i++) {
    String name = mixerInfoList[i].getName();
    byte[] b = name.getBytes(Charset.forName("ISO-8859-1"));
    String strtemp = new String(b);
    String desc = mixerInfoList[i].getDescription();
    if (match(desc, "DirectSound Capture") !=null) {
      inputnames = append(inputnames, strtemp);
      inputindex = append(inputindex,i);
    }
  }
  if (inputnames.length<inputselected) inputselected = 0;
  // Audio format
  format = new AudioFormat((float)sampleRate,bitDepth,2,true,true); // signed, big-endian
  // GUI setting
  setGUI();
}

// -------------------------------------------
public void draw() {
  // background
  background(bgcolor);
  fill(0); stroke(0);
  rect(pX,pY,pW,pH);

  if(flgStart) {
    // data fetch
    float[]envL = rtproc.getEnvL();
    float[]envR = rtproc.getEnvR();
    float[]hrmL = rtproc.getPrdL();
    float[]hrmR = rtproc.getPrdR();
    int ap = rtproc.getAnaPointer();
    int edrawsize = dispDuration*(sampleRate/analysisTimeStep);
    int envsize = envL.length;
    int syldurL = rtproc.getSylDurL();
    int gapdurL = rtproc.getGapDurL();
    int sylcntL = rtproc.getSylCntL();
    int syldurR = rtproc.getSylDurR();
    int gapdurR = rtproc.getGapDurR();
    int sylcntR = rtproc.getSylCntR();
    int waitbyte = rtproc.getWaitByte();
    boolean onL = rtproc.getOnL();
    boolean onR = rtproc.getOnR();
    boolean songL = rtproc.getSongL();
    boolean songR = rtproc.getSongR();
    float dBmag = 1.0f;
    int dBcenter = -60;
    // envelope L
    noFill();
    stroke(255,255,0);
    beginShape();
    for ( int i = 0; i < edrawsize; i++ ) {
      vertex( pX+1+i*pW/edrawsize, pY+pH/4-dBmag*(envL[(ap+i+(envsize-edrawsize))%envsize]-dBcenter));
    }
    endShape();
    // periodicity L
    stroke(0,255,255);
    beginShape();
    for ( int i=0; i<edrawsize; i++ ) {
      vertex( pX+1+i*pW/edrawsize, pY+pH/2-(hrmL[(ap+i+(envsize-edrawsize))%envsize]*0.4f+10));
    }
    endShape();
    // envelope R
    stroke(255,255,0);
    beginShape();
    for ( int i = 0; i < edrawsize; i++ ) {
      vertex( pX+1+i*pW/edrawsize, pY+pH/4*3-dBmag*(envR[(ap+i+(envsize-edrawsize))%envsize]-dBcenter));      
    }
    endShape();
    // periodicity R
    stroke(0,255,255);
    beginShape();
    for ( int i=0; i<edrawsize; i++ ) {
      vertex( pX+1+i*pW/edrawsize, pY+pH-(hrmR[(ap+i+(envsize-edrawsize))%envsize]*0.4f+10));
    }
    endShape();
    // thresholds
    stroke(128,128,0);
    line( pX, pY+pH/4  -dBmag*(threshA1-dBcenter), pX+pW, pY+pH/4  -dBmag*(threshA1-dBcenter) );
    line( pX, pY+pH/4*3-dBmag*(threshA2-dBcenter), pX+pW, pY+pH/4*3-dBmag*(threshA2-dBcenter) );
    stroke(0,128,128);
    line( pX, pY+pH/2-(threshP1*0.4f+10), pX+pW, pY+pH/2-(threshP1*0.4f+10) );
    line( pX, pY+pH  -(threshP2*0.4f+10), pX+pW, pY+pH  -(threshP2*0.4f+10) );
    // text
    textSize(16);
    fill(128,128,255);
    text(str(syldurL),pX+5,pY+19);
    text(str(gapdurL),pX+5,pY+32); 
    fill(255,128,128);
    text(str(sylcntL),pX+5,pY+45); 
    if (!flgStereo) {
      fill(128,128,255);
      text(str(syldurR),pX+5,pY+pH/2+19);
      text(str(gapdurR),pX+5,pY+pH/2+32);
      fill(255,128,128);
      text(str(sylcntR),pX+5,pY+pH/2+45);
    }
    // Buffer occupation
    int bh = PApplet.parseInt(20.0f*waitbyte/datalineBufferSize);
    stroke(128,128,128); noFill();  
    rect(pX-15,pY+pH-25,10,20);
    noStroke();fill(255,96,96);
    rect(pX-15,pY+pH-25+20-bh,10,bh);
    // ON mark
    fill(255,0,0);
    if (onL) rect(pX+pW, pY   , 4, pH/2);
    if (onR) rect(pX+pW, pY+pH, 4, pH/2);
    stroke(255);
    if (songL) ellipse(pX+pW-15,pY+15,20,20);
    if (songR) ellipse(pX+pW-15,pY+pH/2+15,20,20);
    // limitation
    fill(bgcolor); noStroke();
    rect(pX,0,gW-pX,pY);
    rect(pX,pY+pH,gW-pX,gH-pY-pH);
    // boundary
    stroke(196,196,196);
    strokeWeight(2);
    line( pX, pY+pH/2, pX+pW, pY+pH/2);
    strokeWeight(1);
    // refresh audio to flush
    if(flgRefresh && !songL && !songR) {
      refresh();
      flgRefresh = false;
    }
  }
  // refresh every hour
  if( prevtime==59 && minute() == 0 ) flgRefresh = true;
  prevtime = minute();  
}

// ------------------------------------------
public boolean startAudio() {
  // set parameters
  prefix1 = txfPrefix1.getText();
  sylmin1 = PApplet.parseInt(txfSylmin1.getText());
  sylmax1 = PApplet.parseInt(txfSylmax1.getText());
  gapmin1 = PApplet.parseInt(txfGapmin1.getText());    
  gapmax1 = PApplet.parseInt(txfGapmax1.getText());
  threshA1 = PApplet.parseInt(txfThrshA1.getText());
  threshP1 = PApplet.parseInt(txfThrshP1.getText());
  sylmin2 = PApplet.parseInt(txfSylmin2.getText());
  sylmax2 = PApplet.parseInt(txfSylmax2.getText());
  gapmin2 = PApplet.parseInt(txfGapmin2.getText());
  gapmax2 = PApplet.parseInt(txfGapmax2.getText());
  threshA2 = PApplet.parseInt(txfThrshA2.getText());
  threshP2 = PApplet.parseInt(txfThrshP2.getText());
  // construct real-time process
  rtproc = new RTProcess(format,mixerInfoList[inputindex[inputselected]]);
  rtproc.setPriority(Thread.MAX_PRIORITY);
  // cunstruct recornding process
  rtproc.start();
  println("start");
  return true;
}
// ------------------------------------------
public void haltAudio() {
  // quit
  rtproc.quit();    
  println("stop");
}  
// -------------------------------------------
public void refresh() {
  // quit
  haltAudio();
  startAudio();
  // set parameter
  println("refreshed "+nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2));
}
// ----------------------------------------------
public void saveInitfile() {
  PrintWriter writer;
  writer = createWriter("trec.ini"); 
  writer.println(inputselected);
  writer.println(savepath1); 
  writer.println(savepath2); 
  writer.println(prefix1);  
  writer.println(str(sylmin1));
  writer.println(str(sylmax1));
  writer.println(str(gapmin1));
  writer.println(str(gapmax1));
  writer.println(str(threshA1));
  writer.println(str(threshP1));
  writer.println(str(sylnum1));
  writer.println(str(flgStereo));
  writer.println(prefix2);  
  writer.println(str(sylmin2));
  writer.println(str(sylmax2));
  writer.println(str(gapmin2));
  writer.println(str(gapmax2));
  writer.println(str(threshA2));
  writer.println(str(threshP2));
  writer.println(str(sylnum2));
  writer.flush();
  writer.close();
}

//////////////////////////////////////////////////
// GUI and action listeners
//////////////////////////////////////////////////

// Controls
Button    btnSave1,btnSave2,btnStart,btnSet;
TextField txfSave1,txfSave2,txfPrefix1,txfSylmin1,txfSylmax1,txfGapmin1,txfGapmax1,txfThrshA1,txfThrshP1,txfSylnum1,txfPrefix2,txfSylmin2,txfSylmax2,txfGapmin2,txfGapmax2,txfThrshA2,txfThrshP2,txfSylnum2;
Label     lblSave1,lblSave2,lblPrefix1,lblSyl1,lblGap1,lblThrshA1,lblThrshP1,lblSylnum1,lblStereo,lblPrefix2,lblSyl2,lblGap2,lblThrshA2,lblThrshP2,lblSylnum2;
Label     lblInput;
Choice    chcInput;
Checkbox  chbStereo;
TextField[] RchTxfArray;
// -----------------------------------------
public void setGUI() {
  // upper panel
  lblInput = new Label("input");     lblInput.setBounds(   5, 5, 45,20);
  chcInput = new Choice();           chcInput.setBounds(  60, 5,280,20);
  lblSave1 = new Label("path");      lblSave1.setBounds(   5,30, 45,20);
  txfSave1 = new TextField();        txfSave1.setBounds(  60,30,250,20);
  btnSave1 = new Button("...");      btnSave1.setBounds( 315,30, 25,20);
  lblSave2 = new Label("path 2");    lblSave2.setBounds(   5,50, 45,20);
  txfSave2 = new TextField();        txfSave2.setBounds(  60,50,250,20);
  btnSave2 = new Button("...");      btnSave2.setBounds( 315,50, 25,20);
  // left panel
  lblPrefix1 = new Label("prefix");  lblPrefix1.setBounds(  5,pY    ,45,20);
  txfPrefix1 = new TextField();      txfPrefix1.setBounds( 60,pY    ,60,20);
  lblSyl1 = new Label("syllable");   lblSyl1.setBounds(     5,pY+ 20,45,20);
  txfSylmin1 = new TextField();      txfSylmin1.setBounds( 60,pY+ 20,30,20);
  txfSylmax1 = new TextField();      txfSylmax1.setBounds( 90,pY+ 20,30,20);
  lblGap1 = new Label("gap");        lblGap1.setBounds(     5,pY+ 40,45,20);
  txfGapmin1 = new TextField();      txfGapmin1.setBounds( 60,pY+ 40,30,20);
  txfGapmax1 = new TextField();      txfGapmax1.setBounds( 90,pY+ 40,30,20);
  lblThrshA1 = new Label("amp prd"); lblThrshA1.setBounds(  5,pY+ 60,70,20);
  txfThrshA1 = new TextField();      txfThrshA1.setBounds( 60,pY+ 60,30,20);
  txfThrshP1 = new TextField();      txfThrshP1.setBounds( 90,pY+ 60,30,20); 
  lblSylnum1 = new Label("min # syl");lblSylnum1.setBounds( 5,pY+ 80,75,20);
  txfSylnum1 = new TextField();      txfSylnum1.setBounds( 90,pY+ 80,30,20);
  lblStereo = new Label("check if stereo"); lblStereo.setBounds(  5,pY+105,80,20);
  chbStereo = new Checkbox();        chbStereo.setBounds(  100,pY+105,20,20);
  lblPrefix2 = new Label("prefix");  lblPrefix2.setBounds(  5,pY+130,45,20);
  txfPrefix2 = new TextField();      txfPrefix2.setBounds( 60,pY+130,60,20);
  lblSyl2 = new Label("syllable");   lblSyl2.setBounds(     5,pY+150,30,20);  
  txfSylmin2 = new TextField();      txfSylmin2.setBounds( 60,pY+150,30,20);
  txfSylmax2 = new TextField();      txfSylmax2.setBounds( 90,pY+150,30,20);
  lblGap2 = new Label("gap");        lblGap2.setBounds(     5,pY+170,45,20);
  txfGapmin2 = new TextField();      txfGapmin2.setBounds( 60,pY+170,30,20);
  txfGapmax2 = new TextField();      txfGapmax2.setBounds( 90,pY+170,30,20);
  lblThrshA2 = new Label("amp prd"); lblThrshA2.setBounds(  5,pY+190,75,20);
  txfThrshA2 = new TextField();      txfThrshA2.setBounds( 60,pY+190,30,20);
  txfThrshP2 = new TextField();      txfThrshP2.setBounds( 90,pY+190,30,20);
  lblSylnum2 = new Label("min # syl");lblSylnum2.setBounds( 5,pY+210,75,20);
  txfSylnum2 = new TextField();      txfSylnum2.setBounds( 90,pY+210,30,20);
  btnSet = new Button("Set");        btnSet.setBounds(      5,pY+235,45,30);
  btnStart = new Button("Start");    btnStart.setBounds(   50,pY+235,55,30); 
  // Text Field array for Right channel
  TextField[] temp = {txfSave2,txfPrefix2,txfSylmin2,txfSylmax2,txfGapmin2,txfGapmax2,txfThrshA2,txfThrshP2,txfSylnum2};
  RchTxfArray = temp;
  // default value setting
  txfSave1.setText(savepath1);
  txfSave2.setText(savepath2);
  txfPrefix1.setText(prefix1);
  txfSylmin1.setText(str(sylmin1));
  txfSylmax1.setText(str(sylmax1));
  txfGapmin1.setText(str(gapmin1));
  txfGapmax1.setText(str(gapmax1));
  txfThrshA1.setText(str(threshA1));
  txfThrshP1.setText(str(threshP1));
  txfSylnum1.setText(str(sylnum1));
  txfPrefix2.setText(prefix2);
  txfSylmin2.setText(str(sylmin2));
  txfSylmax2.setText(str(sylmax2));
  txfGapmin2.setText(str(gapmin2));
  txfGapmax2.setText(str(gapmax2));
  txfThrshA2.setText(str(threshA2));
  txfThrshP2.setText(str(threshP2));
  txfSylnum2.setText(str(sylnum2));
  // check box
  chbStereo.setLabel("");
  chbStereo.setState(flgStereo);
  for (int i=0; i<RchTxfArray.length; i++) RchTxfArray[i].setEnabled(!flgStereo);
  // choice item
  for(int i=0; i<inputnames.length; i++) chcInput.add(inputnames[i]);
  chcInput.select(inputselected); 
  // listeners
  btnSave1.addActionListener(new BottonActionListener(0));
  btnSave2.addActionListener(new BottonActionListener(1));
  btnSet.addActionListener(new BottonActionListener(2));
  btnStart.addActionListener(new BottonActionListener(3));
  chbStereo.addItemListener(new CheckboxItemListener(0));
  chcInput.addItemListener(new ChoiceItemListener(0));
  // add
  Canvas canvas =(Canvas)surface.getNative();
  JLayeredPane pane =(JLayeredPane)canvas.getParent().getParent();
  pane.add(btnSave1);
  pane.add(btnSave2);
  pane.add(btnSet);
  pane.add(btnStart);
  pane.add(txfSave1);
  pane.add(txfSave2);
  pane.add(txfPrefix1);
  pane.add(txfSylmin1);
  pane.add(txfSylmax1);
  pane.add(txfGapmin1);
  pane.add(txfGapmax1);
  pane.add(txfThrshA1);
  pane.add(txfThrshP1);
  pane.add(txfSylnum1);
  pane.add(txfSylmin2);
  pane.add(txfSylmax2);
  pane.add(txfPrefix2);
  pane.add(txfGapmin2);
  pane.add(txfGapmax2);
  pane.add(txfThrshA2);
  pane.add(txfThrshP2);
  pane.add(txfSylnum2);
  pane.add(lblInput);
  pane.add(lblSave1);
  pane.add(lblSave2);
  pane.add(lblPrefix1);
  pane.add(lblSyl1);
  pane.add(lblGap1);
  pane.add(lblThrshA1);
  pane.add(lblSylnum1);
  pane.add(lblStereo);
  pane.add(lblPrefix2);
  pane.add(lblSyl2);
  pane.add(lblGap2);
  pane.add(lblThrshA2);
  pane.add(lblSylnum2);
  pane.add(chcInput);
  pane.add(chbStereo);
}
// ------------------------------------------------
class BottonActionListener implements ActionListener {
  private int btnid;
  BottonActionListener(int id) { btnid = id; }
  public void actionPerformed(ActionEvent e) {
    // save path 1 button
    if(btnid==0) {
      File folderToStartFrom = new File( savepath1 );
      selectFolder("Select a folder to save:", "folderSelected1", folderToStartFrom );
      // save to inifile
      saveInitfile();
    }
    // save path 2 button
    if(btnid==1) {
      File folderToStartFrom = new File( savepath2 );
      selectFolder("Select a folder to save:", "folderSelected2", folderToStartFrom );
      // save to inifile
      saveInitfile();
    }
    // set button
    if(btnid==2) {
      // set parameters
      prefix1 = txfPrefix1.getText();
      sylmin1 = PApplet.parseInt(txfSylmin1.getText());
      sylmax1 = PApplet.parseInt(txfSylmax1.getText());
      gapmin1 = PApplet.parseInt(txfGapmin1.getText());    
      gapmax1 = PApplet.parseInt(txfGapmax1.getText());
      threshA1 = PApplet.parseInt(txfThrshA1.getText());
      threshP1 = PApplet.parseInt(txfThrshP1.getText());
      sylnum1 = PApplet.parseInt(txfSylnum1.getText());
      sylmin2 = PApplet.parseInt(txfSylmin2.getText());
      sylmax2 = PApplet.parseInt(txfSylmax2.getText());
      gapmin2 = PApplet.parseInt(txfGapmin2.getText());
      gapmax2 = PApplet.parseInt(txfGapmax2.getText());
      threshA2 = PApplet.parseInt(txfThrshA2.getText());
      threshP2 = PApplet.parseInt(txfThrshP2.getText());
      sylnum2 = PApplet.parseInt(txfSylnum1.getText());
      // save to inifile
      saveInitfile();
    }
    // start button
    if(btnid==3) {
      if(flgStart==false) {
        boolean okflg = startAudio();
        if(okflg) { 
          flgStart = true;
          btnStart.setLabel("Stop");
          btnStart.setForeground(Color.red);
          chbStereo.setEnabled(false);
        }
      } else {
        flgStart = false;
        // Halt audio
        haltAudio();
        btnStart.setLabel("Start");
        btnStart.setForeground(Color.black);
        chbStereo.setEnabled(true);
      }
      // save to inifile
      saveInitfile();      
    }
  }
}

class CheckboxItemListener implements ItemListener {
  private int itmid;
  CheckboxItemListener(int id) { itmid = id; }
  public void itemStateChanged(ItemEvent e) {
    if(itmid==0) {
      flgStereo = chbStereo.getState();
      for (int i=0; i<RchTxfArray.length; i++) RchTxfArray[i].setEnabled(!flgStereo);
    }
  }
}
// ----------------------------------------------
class ChoiceItemListener implements ItemListener  {
  private int itmid;
  ChoiceItemListener(int id) { itmid = id; }
  public void itemStateChanged(ItemEvent e) {
    if(itmid==0) {
      inputselected = chcInput.getSelectedIndex();
      println("input: " + inputnames[inputselected]);
    }
  }
}
// ----------------------------------------
public void folderSelected1(File selection) {
  if (selection == null) {
    println("cancelled");
  } else {
    String s = selection.getAbsolutePath();
    savepath1 = s;
    println("Save directory  " + s);
    txfSave1.setText(savepath1);
  }
}
public void folderSelected2(File selection) {
  if (selection == null) {
    println("cancelled");
  } else {
    String s = selection.getAbsolutePath();
    savepath2 = s;
    println("Save directory  " + s);
    txfSave2.setText(savepath2);
  }
}
// Real-time processing thread

class RTProcess extends Thread {
  // Field variables
  private TargetDataLine inputdataline;
  private SyllableDetector SD1, SD2;
  private Recording record;
  private byte[] transBuff,recordBuff;
  private float[] waveformL,waveformR,filteredL,filteredR;
  private float[] envelopeL,envelopeR,periodicL,periodicR;
  private float[] window,wL,wR;
  private double[] A,B,xLp,xRp,yLp,yRp;
  private int wavptr, anaptr, recptr;
  private int timetick,tbsize, awsize, rbsize, atstep, absize;
  private int waitingbytes;
  private long starttime,inputcnt;
  private boolean running,flgOnL, flgOnR;
 
  // Constructor  ---------------------------------------------------
  RTProcess(AudioFormat af, Mixer.Info mi) {
    atstep = analysisTimeStep;
    awsize = analysisWindowSize;
    tbsize = transBufferSize;              // transfer buffer size (in samples)
    rbsize = floor(maxRecordDuration*sampleRate/tbsize)*tbsize; // recording buffer size (in samples)
    absize = rbsize/atstep;                // analyzed buffer size
    timetick = atstep*1000/sampleRate; // 4 ms
    transBuff = new byte[tbsize*bitDepth/8*2];
    recordBuff = new byte[rbsize*bitDepth/8*2];
    waveformL = new float[rbsize];
    waveformR = new float[rbsize];
    filteredL = new float[rbsize];
    filteredR = new float[rbsize];
    envelopeL = new float[absize];
    envelopeR = new float[absize];
    periodicL = new float[absize];
    periodicR = new float[absize];
    wL = new float[awsize];
    wR = new float[awsize];
    window = HanningWindow(awsize);
    FillFilterCoeff();
    xLp = new double[4];
    yLp = new double[4];
    xRp = new double[4];
    yRp = new double[4];
    wavptr = anaptr = recptr = 0;
    inputcnt = 0;
    flgOnL = flgOnR = false; 
    waitingbytes = 0; 
    running = false;
    // Construct sound detector
    SD1 = new SyllableDetector(timetick);
    SD2 = new SyllableDetector(timetick);
    // Open audio input dataline
    try {
      inputdataline = AudioSystem.getTargetDataLine(af,mi);
      inputdataline.open(af,datalineBufferSize);
      inputdataline.start();
      datalineBufferSize = inputdataline.getBufferSize();
    } catch(Exception e) { 
      println(e);
    }
  }
  // Methods  ----------------------------------------------------------
  public float[] getEnvL()  { return envelopeL; } 
  public float[] getEnvR()  { return envelopeR; }
  public float[] getPrdL()  { return periodicL; }
  public float[] getPrdR()  { return periodicR; }
  public int getAnaPointer()  { return anaptr; } 
  public int getSylDurL() { return SD1.currentSylDur(); }
  public int getGapDurL() { return SD1.currentGapDur(); }
  public int getSylCntL() { return SD1.currentSylCnt(); }
  public int getSylDurR() { return SD2.currentSylDur(); }
  public int getGapDurR() { return SD2.currentGapDur(); }
  public int getSylCntR() { return SD2.currentSylCnt(); }
  public int getWaitByte() { return waitingbytes; };
  public boolean getOnL() { return flgOnL; };
  public boolean getOnR() { return flgOnR; };
  public boolean getSongL() { return SD1.getSongState() ; }
  public boolean getSongR() { return SD2.getSongState() ; }
  public long getStartTime() { return starttime; }

  // calculate recording bytes ------------------------------------------------
  private byte[] getRecordBytes(long currentcnt, long onsetcnt, long offsetcnt) {
    int rblen = recordBuff.length;
    int onsetptr  = (recptr-(PApplet.parseInt(currentcnt- onsetcnt)*atstep+margin*sampleRate/1000)*2*2+rblen)%rblen; // 2byte * 2ch
    int offsetptr = (recptr-(PApplet.parseInt(currentcnt-offsetcnt)*atstep)*2*2+rblen)%rblen; // 
    int len = (offsetptr-onsetptr+rblen)%rblen;
    byte[] recbytes = new byte[len];
    for(int i=0; i<len; i++) {
      recbytes[i] = recordBuff[(onsetptr+i)%rblen];
    }
    return recbytes;
  }
  // window definition --------------------------------------------------------
  private float[] HanningWindow(int winsize) {
    float[] win = new float[winsize];
    for (int i=0; i<winsize; i++) {
        win[i] = 0.5f*(1.0f-cos(2.0f*PI*i/winsize));
    }
    return win;
  }
  // filter coefficient =------------------------------------------------------
  public void FillFilterCoeff() {
    // 2nd-order Butterworth [1000 8000]/(fs/2) 
    double[] fA = {1.0f,-1.830438899724121f,1.180972230227647f,-0.486121460220382f,0.180972230227647f};
    double[] fB = {0.237643994385108f,0.0f,-0.475287988770215f,0.0f,0.237643994385108f};
    A = fA; B = fB;
  }
  // control ------------------------------------------------------------------
  public void start() {
    running = true;
    starttime = System.currentTimeMillis();
    super.start(); 
  }
  public void quit()  { 
    running = false;
    try {
      inputdataline.close();
    } catch(Exception e) { println(e); }
  }
  // run process --------------------------------------------------------------
  public void run () {
    while (running) {
      // transfer interval should be 32 ms (1024/32000)
      try {
        int avb = inputdataline.available();
        waitingbytes = avb;
        if( avb >= transBuff.length ) { 
          // read audio buffer
          inputdataline.read( transBuff, 0, transBuff.length );
          // copy to recording buffer
          arrayCopy(transBuff,0,recordBuff,recptr,transBuff.length);
          recptr = (recptr+transBuff.length)%recordBuff.length;
          // convert to waveform data (from byte stream to 16bit stereo [-1.0~+1.0])
          ByteArrayInputStream bais = new ByteArrayInputStream(transBuff);
          DataInputStream dis = new DataInputStream(bais);
          double xL,xR,yL,yR;
          for(int i=0; i<tbsize; i++) {
            xL = (float)dis.readShort()/32768.0f;            
            xR = (float)dis.readShort()/32768.0f;
            // band-pass filtering 
            yL = B[0]*xL; yR = B[0]*xR;
            for (int n=0; n<4; n++) {
              yL += B[n+1]*xLp[0] - A[n+1]*yLp[n];
              yR += B[n+1]*xRp[0] - A[n+1]*yRp[n];
            }
            for (int n=2; n>=0; n--) {
              xLp[n+1]=xLp[n];
              xRp[n+1]=xRp[n];
              yLp[n+1]=yLp[n];
              yRp[n+1]=yRp[n];
            }
            xLp[0] = xL; xRp[0] = xR;
            yLp[0] = yL; yRp[0] = yR;
            waveformL[(wavptr+i)%rbsize] = (float)xL;
            waveformR[(wavptr+i)%rbsize] = (float)xR;
            filteredL[(wavptr+i)%rbsize] = (float)yL;
            filteredR[(wavptr+i)%rbsize] = (float)yR;
          }
          // Process for every analysis timestep
          for(int s=0; s<tbsize/atstep; s++) {
            // Envelope
            double sumL = 0.0f, sumR = 0.0f;
            for(int n=0; n<awsize; n++) {
              int idx = wavptr+(s+1)*atstep-awsize;
              wL[n] = filteredL[(idx+n+rbsize)%rbsize]*window[n];
              wR[n] = filteredR[(idx+n+rbsize)%rbsize]*window[n];
              sumL += (double)wL[n]*wL[n];
              sumR += (double)wR[n]*wR[n];
            }
            float eL = 10.0f*log((float)(sumL/awsize))/2.3026f; // log(10) = 2.3026
            float eR = 10.0f*log((float)(sumR/awsize))/2.3026f;            
            // YIN algorithm for detecting periodicity and f0
            float tempL = 0.0f, tempR = 0.0f;
            float minvalL = 1.0f, minvalR = 1.0f;
            float dL=1.0f,dR=1.0f;
            for(int tau=1; tau<yinParam; tau++) {
              for (int n=0; n<awsize-tau; n++) {
                dL += (wL[n]-wL[n+tau])*(wL[n]-wL[n+tau]);
                dR += (wR[n]-wR[n+tau])*(wR[n]-wR[n+tau]);
              }
              tempL += dL;
              tempR += dR;
              dL = dL/((1.0f/tau)*tempL);
              dR = dR/((1.0f/tau)*tempR);
              if (tau>4 & dL<minvalL) minvalL = dL; // upper limiting <8000Hz
              if (tau>4 & dR<minvalR) minvalR = dR;
            }
            float pL = (1-minvalL)*100;
            float pR = (1-minvalR)*100;
            // save to buffer
            envelopeL[(anaptr+s)%absize] = eL;
            envelopeR[(anaptr+s)%absize] = eR;
            periodicL[(anaptr+s)%absize] = pL;
            periodicR[(anaptr+s)%absize] = pR;
            // Sound state
            flgOnL = eL>=threshA1 && pL>=threshP1;
            flgOnR = eR>=threshA2 && pR>=threshP2;
            // Push sound state into state-machine sound detector
            SD1.input(flgOnL,sylmin1,sylmax1,gapmin1,gapmax1,sylnum1);
            SD2.input(flgOnR,sylmin2,sylmax2,gapmin2,gapmax2,sylnum2);
            inputcnt++;
          }
          // pointer increment
          anaptr = (anaptr+(tbsize/atstep))%absize;
          wavptr = (wavptr+tbsize)%rbsize;
        }
      } catch (Exception e) { println(e); }
      if (SD1.getRecordState()) {
        long onset = SD1.getSongOnsetCount();
        long offset = SD1.getSongOffsetCount();
        byte[] recbytes = getRecordBytes(inputcnt,onset,offset);
        long onsettime = starttime+onset*timetick;
        record = new Recording(recbytes,onsettime,true);
        record.start();
      }
      if (!flgStereo) {
        if (SD2.getRecordState()) {
          long onset = SD1.getSongOnsetCount();
          long offset = SD1.getSongOffsetCount();
          byte[] recbytes = getRecordBytes(inputcnt,onset,offset);
          long onsettime = starttime+onset*timetick;
          record = new Recording(recbytes,onsettime,false);
          record.start();
        }
      }
    }
  }
}

//////////////////////////////////////////////////////////////////
class SyllableDetector {
  // Field variables ------------------------------------------
  private long inputcnt,songOnsetCount,songOffsetCount;
  private int syldur, gapdur;
  private int timetick;
  private int oncnt, offcnt, cbsize,cbwptr,cbrptr,sylcnt;
  private byte sdState;
  private boolean flgSongDetected,flgRecord;
  
  // Constructor -----------------------------------------------
  SyllableDetector(int tt) {
    timetick = tt;
    inputcnt = 0;
    sdState = 0;
    syldur = gapdur = 0;
    oncnt = offcnt = sylcnt = 0;
    cbsize = 100; cbwptr = cbrptr = 0;
    flgSongDetected = false;
  }
  // Methods ---------------------------------------------------
  public int currentSylDur() { return syldur; }
  public int currentGapDur() { return gapdur; }
  public int currentSylCnt() { return sylcnt; }
  // count available sound logs
  public int available() { return (cbwptr-cbrptr+cbsize)%cbsize; }
  public boolean getSongState() { return flgSongDetected; };
  public boolean getRecordState() { boolean rs = flgRecord; flgRecord = false; return rs; }
  public long getSongOnsetCount() { return songOnsetCount; }
  public long getSongOffsetCount() { return songOffsetCount; }
  // Input to state machine
  public void input(boolean flgOn, int smin, int smax, int gmin, int gmax, int snum) {
    boolean flgSylDetected = false, flgFinalize = false;
    // count
    inputcnt++;
    //  sdState...
    //    0: "Idle"
    //    1: "SoundOn"   above threshold, count on_duration
    //    2: "Syllable"
    //    3: "SoundOff"  under threhold, count off_duration
    //    4: "Gap"
    switch (sdState) {
      // "Idling" state
      case 0:
        // to "SoundOn"
        if (flgOn) { oncnt = 1; sdState = 1; } 
        break;
      // "SoundOn" state
      case 1:
        if (flgOn) {
          oncnt++;
          // to "Syllable" state when ondur >= sylmin
          if (oncnt*timetick>=smin) {
            // gap detetected!
            if (offcnt!=0) gapdur = offcnt*timetick;
            offcnt = 0;
            sdState = 2; 
          } 
        } else {
          // to "Gap" state when sound off during small sound
          if (offcnt!=0) { offcnt++;   sdState = 4; } 
          // to "SoundOff" state
          else           { offcnt = 1; sdState = 3; }
        }
        break;
      // "Syllable" state
      case 2:
        if (flgOn) {
          oncnt++;
          // reset all and go to "TooLong" state when ondur > sylmax
          if (oncnt*timetick>smax) { 
            flgFinalize = true;
            sdState = 5;
          }
        } else {
          // to "SoundOff" state when sound off
          offcnt = 1; sdState = 3;
        }
        break;       
      // "SoundOff" state
      case 3: 
        if (!flgOn) {
          offcnt++;
          // to "Gap" state when offdur >= gapmin
          if (offcnt*timetick>=gmin) {
            if (oncnt!=0) {
              // syllable detected!
              syldur = oncnt*timetick;
              flgSylDetected = true;
            }
            oncnt = 0;
            sdState = 4;
          }
        } else {
          // to "Syllable" state when sound on during small gap
          if (oncnt!=0) { oncnt++;   sdState = 2; }
          // to "SoundOn" state
          else          { oncnt = 1; sdState = 1; }
        }
        break;
      // "Gap" state
      case 4:
        if (!flgOn) {
          offcnt++;
          // finalize and go to "Idle" state when offdur > gapmax
          if (offcnt*timetick>gmax) { 
            flgFinalize = true;
            sdState = 0;
          }
        } else {
          // to "SoundOn" state
          oncnt = 1; sdState = 1;
        }
        break;
      // "TooLong" state 
      case 5:
        // to "Idle" state when sound off
        if(!flgOn) sdState = 0;
        break;
    }
    // Finalize 
    if(flgFinalize) {
      if (flgSongDetected) {
        // Recording command here
        songOffsetCount = inputcnt;
        flgRecord = true;
      }
      syldur = gapdur = sylcnt = oncnt = offcnt = 0; 
      flgSongDetected = false;
    }
    // action after syllable detection
    if(flgSylDetected) {
      if (gapdur==0) {
        sylcnt = 1;
        songOnsetCount = inputcnt-syldur/timetick-1;
      } else {
        sylcnt++;
      }
      if (sylcnt>=snum) flgSongDetected = true;
      flgSylDetected = false;
    }
  }
}
class Recording extends Thread {
  // Field variables
  private byte[] recdat;
  private long rectime;
  private boolean saveLeftCh;

  // Constructor
  Recording(byte[] rb, long rt, boolean lc) {
    recdat = rb;
    rectime = rt;
    saveLeftCh = lc;
  }
  // Methods
  public void start() {
    super.start();
  }
  public void run () {
    AudioFormat fmt;
    byte[] recdat2;
    String fname;
    long numframes;
    if (flgStereo) {
      // Stereo
      fmt = new AudioFormat((float)sampleRate,bitDepth,2,true,true); // stereo, signed, big-endian
      fname = savepath1 +"/" + prefix1 +"_"+ millis2datestr(rectime) +".wav";
      recdat2 = recdat;
      numframes = recdat2.length/4;
    } else {
      // Monaural
      fmt = new AudioFormat((float)sampleRate,bitDepth,1,true,true); // monaural, signed, big-endian
      recdat2 = new byte[recdat.length/2];
      if (saveLeftCh) {
        // save left channel as monoral
        fname = savepath1 +"/" + prefix1 +"_"+ millis2datestr(rectime) +".wav";
        for (int i=0; i<recdat2.length/2; i++) {
          recdat2[i*2+0] = recdat[i*4+0];
          recdat2[i*2+1] = recdat[i*4+1];
        }
      } else {
        // save right channel as monoral
        fname = savepath2 +"/" + prefix2 +"_"+ millis2datestr(rectime) +".wav";
        for (int i=0; i<recdat2.length/2; i++) {
          recdat2[i*2+0] = recdat[i*4+2];
          recdat2[i*2+1] = recdat[i*4+3];
        }
      }
      numframes = recdat2.length/2;
    }
    ByteArrayInputStream baiStream = new ByteArrayInputStream(recdat2);
    AudioInputStream aiStream = new AudioInputStream(baiStream,fmt,numframes);
    println("record: "+fname);
    // create and write audio file
    File audioFile = new File(fname);
    try {
      AudioSystem.write(aiStream,AudioFileFormat.Type.WAVE,audioFile);
      aiStream.close();
      baiStream.close();
    } catch (IOException e) {
      println(e);
    }
  }
}
// Millisecond to Date string ------------------- 
public String millis2datestr(long t) {
  Calendar cal = Calendar.getInstance(TimeZone.getDefault());
  cal.setTimeInMillis(t);
  int y = cal.get(Calendar.YEAR);  
  int m = cal.get(Calendar.MONTH) + 1;
  int d = cal.get(Calendar.DATE); 
  int h = cal.get(Calendar.HOUR_OF_DAY);
  int min = cal.get(Calendar.MINUTE);
  int sec = cal.get(Calendar.SECOND);
  int ms = cal.get(Calendar.MILLISECOND); 
  String str = nf(y,4)+nf(m,2)+nf(d,2)+"-"+nf(h,2)+nf(min,2)+nf(sec,2)+"-"+nf(ms,3);
  return str;
}

// Date string to millisecond ------------------
public long datestr2millis(String str) {
  Calendar cal = Calendar.getInstance(TimeZone.getDefault());
  int y = Integer.parseInt(str.substring(0,4)); 
  int m = Integer.parseInt(str.substring(4,6));
  int d = Integer.parseInt(str.substring(6,8));
  int h = Integer.parseInt(str.substring(9,11));
  int min = Integer.parseInt(str.substring(11,13));
  int sec = Integer.parseInt(str.substring(13,15));
  int ms = Integer.parseInt(str.substring(16));
  cal.setTimeInMillis(ms);
  cal.set(y,m-1,d,h,min,sec);
  return cal.getTimeInMillis();  
}
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "tRec10" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
