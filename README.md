# tRec
Processing based sound recorder for "solo" song of songbird. This program has been developed to be used mainly for Bengalese and zebra finches, but you might try to use for other vocalizing animals.

Sampling is fixed in 32-kHz, 16-bit, stereo format. The tRec program always monitor "left" channel of selected input port to detect an initiation of singing and start recording. The recorded song is saved to local storage which you selected as a WAV file in the stereo format (including left and right channels).

tRec.pde is main PDE file for song recording. 

RecordingBuffer.pde describes a class for the recording buffer that temporarily hold sound to monitor and record songs.

Recording.pde contains a class that saves recorded sound in WAV file.




