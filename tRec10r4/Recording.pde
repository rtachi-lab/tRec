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
  void start() {
    super.start();
  }
  void run () {
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
