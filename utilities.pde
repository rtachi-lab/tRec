// Millisecond to Date string ------------------- 
String millis2datestr(long t) {
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
long datestr2millis(String str) {
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
