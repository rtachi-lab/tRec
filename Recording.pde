class Recording extends Thread {
  private RecordingBuffer rb;
  private AudioFormat fmt;
  private boolean running;
 
  // Constructor
  Recording(RecordingBuffer r, AudioFormat f) {
    rb = r;
    fmt = f;
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
      if(rb.getRecFlag()==true) {
        Date dt = new Date(rb.getStartTime());
        Calendar cl = Calendar.getInstance();
        cl.setTime(dt);
        int yr = cl.get(Calendar.YEAR);
        int mt = cl.get(Calendar.MONTH)+1;
        int dy = cl.get(Calendar.DATE);
        int hr = cl.get(Calendar.HOUR_OF_DAY);
        int mn = cl.get(Calendar.MINUTE);
        int sc = cl.get(Calendar.SECOND);
        int ml = cl.get(Calendar.MILLISECOND);
       
        String dates = nf(yr,4)+nf(mt,2)+nf(dy,2);
        String times = nf(hr,2)+nf(mn,2)+nf(sc,2);
        String ms = nf(ml,3);
        String fname = outpath +"/" + prefix +"_"+ dates +"_"+ times +"_"+ ms +".wav";
        println(fname);
        File audioFile = new File(fname);
        byte[] recdat = rb.getRecordingBytes();
        ByteArrayInputStream baiStream = new ByteArrayInputStream(recdat);
        AudioInputStream aiStream = new AudioInputStream(baiStream,fmt,recdat.length/4);
        try {
          AudioSystem.write(aiStream,AudioFileFormat.Type.WAVE,audioFile);
          aiStream.close();
          baiStream.close();
        } catch (IOException e) {
          println(e);
        }
        //println("saved");
        rb.setRecFlag(false);
      }
    }
  }
}
