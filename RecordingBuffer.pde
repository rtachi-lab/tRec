class RecordingBuffer extends Thread {
  // member variables
  private byte[] transBuff;
  private byte[] recordBuff;
  private float[] waveformL;
  private float[] waveformR;
  private float[] envelopeL;
  private float[] envelopeR;
  private boolean running,flgRec;
  private int wp, ep, tbsize, rbsize,envstep,envsize;
  private int flgOn, flgRise, oncnt, offcnt, sylcnt, gapcnt, syldur, gapdur, elmcnt;
  private int startid, endid, recdur, temp01;
  private float prevwav;
  private long starttime;
 
  // Constructor
  RecordingBuffer() {
    tbsize = transBufferSize;
    rbsize = maxRecordDuration*sampleRate;
    envstep = sampleRate/1000;
    envsize = rbsize/envstep;
    transBuff = new byte[tbsize*bitResolution/8*2];
    recordBuff = new byte[rbsize*bitResolution/8*2];
    waveformL = new float[rbsize];
    waveformR = new float[rbsize];
    envelopeL = new float[envsize];
    envelopeR = new float[envsize];
    wp = 0;
    ep = 0;
    prevwav = 0.0;
    flgOn = 0;
    flgRise = 0;
    oncnt = 0;
    offcnt = 0;
    sylcnt = 0;
    gapcnt = 0;
    syldur = 0;
    gapdur = 0;
    elmcnt = 0;
    startid = 0;
    endid = 0;
    recdur = 0;
    temp01 = 0;
    starttime = 0;
    flgRec = false;
    running = false;
  }
  // Methods
  float[] getWave() {
    return waveformL;
  }
  int getWavePointer() {
    return wp;
  }  
  float[] getEnv() {
    return envelopeL;
  }
  int getEnvPointer() {
    return ep;
  }  
  int getSyl() {
    return syldur;
  }
  int getGap() {
    return gapdur;
  }
  int getElm() {
    return elmcnt;
  }
  int getStartID() {
    return startid;
  }
  int getEndID() {
    return endid;
  }
  int getRecDur() {
    return recdur;
  }
  boolean getRecFlag() {
    return flgRec;
  }
  void setRecFlag(boolean b) {
    flgRec = b;
  }
  byte[] getRecordingBytes() {
    int startptr = startid*envstep*bitResolution/8*2;
    int endptr =  endid*envstep*bitResolution/8*2;
    int len = (endptr-startptr+recordBuff.length)%recordBuff.length;
    byte[] recbytes = new byte[len];
    for(int i=0; i<len; i++) {
      recbytes[i] = recordBuff[(startptr+i)%recordBuff.length];
    }
    return recbytes;      
  }
  long getStartTime() {
    return starttime;
  }
  int getTempVal() {
    return temp01;
  }
 
  // start  
  void start () {
    running = true;
    super.start();
  }
  void quit () {
    running = false;
  }
  // run
  void run () {
    while (running) {
      try { sleep(4); } catch (Exception e) { }
      try {
        if(target.available()>transBuff.length) {
          target.read( transBuff , 0, transBuff.length );
          for(int i=0; i<transBuff.length; i++) {
            recordBuff[(wp*bitResolution/8*2+i)%recordBuff.length] = transBuff[i];
          }
          ByteArrayInputStream bais = new ByteArrayInputStream(transBuff);
          DataInputStream dis = new DataInputStream(bais);
          for(int i=0; i<tbsize; i++) {
            waveformL[(wp+i)%rbsize] = (float)dis.readShort()/32768.0;            
            waveformR[(wp+i)%rbsize] = (float)dis.readShort()/32768.0;
          }
          // Calc envelope
          for(int i=0; i<tbsize/envstep; i++) {
            float sum = 0.0;
            for(int j=0; j<envstep; j++) {
              float temp = waveformL[(wp+(i*envstep)+j)%rbsize];
              sum += (temp-prevwav)*(temp-prevwav);
              prevwav = temp;
            }
            envelopeL[(ep+i)%envsize] = 10.0*log(sum/16.0)/log(10.0);
          }
          // Song detection
          for(int i=0; i<tbsize/envstep; i++) {
            if( envelopeL[(ep+i)%envsize] > thresh ) { flgOn = 1; offcnt = 0; }
            else { flgOn = 0; oncnt = 0; }
            oncnt += flgOn;
            offcnt += (1-flgOn);
            if( flgRise==0 && oncnt>=sylmin ) {
              flgRise = 1;
              sylcnt = sylmin;
              gapdur = gapcnt-sylmin;
              if( elmcnt==0 ) { 
                startid = (ep+i-syldur-gapdur-sylmin-gapmax+envsize)%envsize; // gapdur,syldur,sylmin,gapmaxだけ巻き戻す
                starttime = System.currentTimeMillis()-syldur-gapdur-sylmin-gapmax;
              }
              if( syldur<=sylmax && gapdur<gapmax ) { elmcnt++; }
            }
            if( flgRise==1 && offcnt>=gapmin ) {
              flgRise = 0;
              gapcnt = gapmin;
              syldur = sylcnt-gapmin;
            }
            sylcnt += flgRise;
            gapcnt += (1-flgRise);
            if( sylcnt>sylmax || gapcnt>gapmax ) {
              if( elmcnt>=sylnum ) {
                flgRec = true;
                endid = (ep+i)%envsize;
                recdur = (endid-startid+envsize)%envsize;
              }
              elmcnt = 0;
            }
          }
          ep = (ep+(tbsize/envstep))%envsize;
          wp = (wp+tbsize)%rbsize;
        }
      } catch (IOException e) { println(e); }
    }
  }
}
