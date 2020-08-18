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
//   read audio dataline buffer every 32 ms (=1024/32000)
//   windowsize: 256 (8 ms)
//   timestep: 64 (2 ms)
//   maximum recordable duration: 30 seconds
//   display duration: 2 seconds
//   dataline buffer is 8 times larger than transfer buffer (1024*4bytes*8)
//      this should not affect the latancy
int sampleRate = 32000;
int bitDepth = 16;
int transBufferSize = 1024; 
int analysisWindowSize = 256;
int analysisTimeStep = 64;
int yinParam = 100; // lower limit: 1000 Hz. Must be smaller than analysisWindowSize
int maxRecordDuration = 30;
int dispDuration = 2;
int datalineBufferSize = transBufferSize *4*8;
int margin = 200; // 200 ms margin will be inserted at the song onset

// display setting
int gW = 345;
int gH = 345;
int pX = 125;
int pY = 75;
int pW = 215;
int pH = 265;
int bgcolor = 240;

// -------------------------------------------
void settings() {
    size(gW, gH);
}
void setup() {  
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
    inputselected = int(lines[0]);
    if (lines[1].length()==0) savepath1 = System.getProperty("user.dir");
    else savepath1 = lines[1];
    if (lines[2].length()==0) savepath2 = System.getProperty("user.dir");
    else savepath2 = lines[2];
    prefix1 = lines[3];
    sylmin1 = int(lines[4]);
    sylmax1 = int(lines[5]);
    gapmin1 = int(lines[6]);
    gapmax1 = int(lines[7]);
    threshA1 = int(lines[8]);
    threshP1 = int(lines[9]);
    sylnum1 = int(lines[10]);
    flgStereo = boolean(lines[11]);
    prefix2 = lines[12];
    sylmin2 = int(lines[13]);
    sylmax2 = int(lines[14]);
    gapmin2 = int(lines[15]);
    gapmax2 = int(lines[16]);
    threshA2 = int(lines[17]);
    threshP2 = int(lines[18]);
    sylnum2 = int(lines[19]);
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
void draw() {
  // background
  background(bgcolor);
  fill(0); stroke(0);
  rect(pX,pY,pW,pH);

  if(flgStart) {
    // data fetch
    float[]envL = rtproc.getEnvL();
    float[]envR = rtproc.getEnvR();
    float[]prdL = rtproc.getPrdL();
    float[]prdR = rtproc.getPrdR();
    int ap = rtproc.getAnaPointer();
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
    float dBmag = 1.0;
    int dBcenter = -60;
    // envelope L
    noFill();
    stroke(255,255,0);
    beginShape();
    for ( int i = 0; i < envsize; i++ ) {
      vertex( pX+1+i*pW/envsize, pY+pH/4-dBmag*(envL[(ap+i)%envsize]-dBcenter));
    }
    endShape();
    // periodicity L
    stroke(0,255,255);
    beginShape();
    for ( int i=0; i < envsize; i++ ) {
      vertex( pX+1+i*pW/envsize, pY+pH/2-(prdL[(ap+i)%envsize]*0.4+10));
    }
    endShape();
    // envelope R
    stroke(255,255,0);
    beginShape();
    for ( int i = 0; i < envsize; i++ ) {
      vertex( pX+1+i*pW/envsize, pY+pH/4*3-dBmag*(envR[(ap+i)%envsize]-dBcenter));      
    }
    endShape();
    // periodicity R
    stroke(0,255,255);
    beginShape();
    for ( int i=0; i < envsize; i++ ) {
      vertex( pX+1+i*pW/envsize, pY+pH-(prdR[(ap+i)%envsize]*0.4+10));
    }
    endShape();
    // thresholds
    stroke(128,128,0);
    line( pX, pY+pH/4  -dBmag*(threshA1-dBcenter), pX+pW, pY+pH/4  -dBmag*(threshA1-dBcenter) );
    line( pX, pY+pH/4*3-dBmag*(threshA2-dBcenter), pX+pW, pY+pH/4*3-dBmag*(threshA2-dBcenter) );
    stroke(0,128,128);
    line( pX, pY+pH/2-(threshP1*0.4+10), pX+pW, pY+pH/2-(threshP1*0.4+10) );
    line( pX, pY+pH  -(threshP2*0.4+10), pX+pW, pY+pH  -(threshP2*0.4+10) );
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
    int bh = int(20.0*waitbyte/datalineBufferSize);
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
boolean startAudio() {
  // set parameters
  prefix1 = txfPrefix1.getText();
  sylmin1 = int(txfSylmin1.getText());
  sylmax1 = int(txfSylmax1.getText());
  gapmin1 = int(txfGapmin1.getText());    
  gapmax1 = int(txfGapmax1.getText());
  threshA1 = int(txfThrshA1.getText());
  threshP1 = int(txfThrshP1.getText());
  sylmin2 = int(txfSylmin2.getText());
  sylmax2 = int(txfSylmax2.getText());
  gapmin2 = int(txfGapmin2.getText());
  gapmax2 = int(txfGapmax2.getText());
  threshA2 = int(txfThrshA2.getText());
  threshP2 = int(txfThrshP2.getText());
  // construct real-time process
  rtproc = new RTProcess(format,mixerInfoList[inputindex[inputselected]]);
  rtproc.setPriority(Thread.MAX_PRIORITY);
  // cunstruct recornding process
  rtproc.start();
  println("start");
  return true;
}
// ------------------------------------------
void haltAudio() {
  // quit
  rtproc.quit();    
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
// ----------------------------------------------
void saveInitfile() {
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
void setGUI() {
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
      sylmin1 = int(txfSylmin1.getText());
      sylmax1 = int(txfSylmax1.getText());
      gapmin1 = int(txfGapmin1.getText());    
      gapmax1 = int(txfGapmax1.getText());
      threshA1 = int(txfThrshA1.getText());
      threshP1 = int(txfThrshP1.getText());
      sylnum1 = int(txfSylnum1.getText());
      sylmin2 = int(txfSylmin2.getText());
      sylmax2 = int(txfSylmax2.getText());
      gapmin2 = int(txfGapmin2.getText());
      gapmax2 = int(txfGapmax2.getText());
      threshA2 = int(txfThrshA2.getText());
      threshP2 = int(txfThrshP2.getText());
      sylnum2 = int(txfSylnum1.getText());
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
void folderSelected1(File selection) {
  if (selection == null) {
    println("cancelled");
  } else {
    String s = selection.getAbsolutePath();
    savepath1 = s;
    println("Save directory  " + s);
    txfSave1.setText(savepath1);
  }
}
void folderSelected2(File selection) {
  if (selection == null) {
    println("cancelled");
  } else {
    String s = selection.getAbsolutePath();
    savepath2 = s;
    println("Save directory  " + s);
    txfSave2.setText(savepath2);
  }
}
