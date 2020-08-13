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
  float[] getEnvL()  { return envelopeL; } 
  float[] getEnvR()  { return envelopeR; }
  float[] getPrdL()  { return periodicL; }
  float[] getPrdR()  { return periodicR; }
  int getAnaPointer()  { return anaptr; } 
  int getSylDurL() { return SD1.currentSylDur(); }
  int getGapDurL() { return SD1.currentGapDur(); }
  int getSylCntL() { return SD1.currentSylCnt(); }
  int getSylDurR() { return SD2.currentSylDur(); }
  int getGapDurR() { return SD2.currentGapDur(); }
  int getSylCntR() { return SD2.currentSylCnt(); }
  int getWaitByte() { return waitingbytes; };
  boolean getOnL() { return flgOnL; };
  boolean getOnR() { return flgOnR; };
  boolean getSongL() { return SD1.getSongState() ; }
  boolean getSongR() { return SD2.getSongState() ; }
  long getStartTime() { return starttime; }

  // calculate recording bytes ------------------------------------------------
  private byte[] getRecordBytes(long currentcnt, long onsetcnt, long offsetcnt) {
    int rblen = recordBuff.length;
    int onsetptr  = (recptr-(int(currentcnt- onsetcnt)*atstep+margin*sampleRate/1000)*2*2+rblen)%rblen; // 2byte * 2ch
    int offsetptr = (recptr-(int(currentcnt-offsetcnt)*atstep)*2*2+rblen)%rblen; // 
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
        win[i] = 0.5*(1.0-cos(2.0*PI*i/winsize));
    }
    return win;
  }
  // filter coefficient =------------------------------------------------------
  void FillFilterCoeff() {
    // 2nd-order Butterworth [1000 8000]/(fs/2) 
    double[] fA = {1.0,-1.830438899724121,1.180972230227647,-0.486121460220382,0.180972230227647};
    double[] fB = {0.237643994385108,0.0,-0.475287988770215,0.0,0.237643994385108};
    A = fA; B = fB;
  }
  // control ------------------------------------------------------------------
  void start() {
    running = true;
    starttime = System.currentTimeMillis();
    super.start(); 
  }
  void quit()  { 
    running = false;
    try {
      inputdataline.close();
    } catch(Exception e) { println(e); }
  }
  // run process --------------------------------------------------------------
  void run () {
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
            xL = (float)dis.readShort()/32768.0;            
            xR = (float)dis.readShort()/32768.0;
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
            double sumL = 0.0, sumR = 0.0;
            for(int n=0; n<awsize; n++) {
              int idx = wavptr+(s+1)*atstep-awsize;
              wL[n] = filteredL[(idx+n+rbsize)%rbsize]*window[n];
              wR[n] = filteredR[(idx+n+rbsize)%rbsize]*window[n];
              sumL += (double)wL[n]*wL[n];
              sumR += (double)wR[n]*wR[n];
            }
            float eL = 10.0*log((float)(sumL/awsize))/2.3026; // log(10) = 2.3026
            float eR = 10.0*log((float)(sumR/awsize))/2.3026;            
            // YIN algorithm for detecting periodicity and f0
            float tempL = 0.0, tempR = 0.0;
            float minvalL = 1.0, minvalR = 1.0;
            float dL=1.0,dR=1.0;
            for(int tau=1; tau<yinParam; tau++) {
              for (int n=0; n<awsize-tau; n++) {
                dL += (wL[n]-wL[n+tau])*(wL[n]-wL[n+tau]);
                dR += (wR[n]-wR[n+tau])*(wR[n]-wR[n+tau]);
              }
              tempL += dL;
              tempR += dR;
              dL = dL/((1.0/tau)*tempL);
              dR = dR/((1.0/tau)*tempR);
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
  int currentSylDur() { return syldur; }
  int currentGapDur() { return gapdur; }
  int currentSylCnt() { return sylcnt; }
  // count available sound logs
  int available() { return (cbwptr-cbrptr+cbsize)%cbsize; }
  boolean getSongState() { return flgSongDetected; };
  boolean getRecordState() { boolean rs = flgRecord; flgRecord = false; return rs; }
  long getSongOnsetCount() { return songOnsetCount; }
  long getSongOffsetCount() { return songOffsetCount; }
  // Input to state machine
  void input(boolean flgOn, int smin, int smax, int gmin, int gmax, int snum) {
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
