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
      prefix2 = txfPrefix2.getText();
      sylmin2 = int(txfSylmin2.getText());
      sylmax2 = int(txfSylmax2.getText());
      gapmin2 = int(txfGapmin2.getText());
      gapmax2 = int(txfGapmax2.getText());
      threshA2 = int(txfThrshA2.getText());
      threshP2 = int(txfThrshP2.getText());
      sylnum2 = int(txfSylnum2.getText());
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
