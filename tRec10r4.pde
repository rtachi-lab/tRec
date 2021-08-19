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
  prefix2 = txfPrefix2.getText();
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
