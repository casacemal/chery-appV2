/// Android KeyCodes enumeration
/// Based on Android KeyEvent class and Jekso/AndroidTV-Remote-Controller
enum KeyCodes {
  // Navigation Keys
  keyCodeHome(3, 'Home'),
  keyCodeBack(4, 'Back'),
  keyCodeDpadUp(19, 'D-Pad Up'),
  keyCodeDpadDown(20, 'D-Pad Down'),
  keyCodeDpadLeft(21, 'D-Pad Left'),
  keyCodeDpadRight(22, 'D-Pad Right'),
  keyCodeDpadCenter(23, 'D-Pad Center'),
  
  // System Keys
  keyCodePower(26, 'Power'),
  keyCodeAppSwitch(187, 'App Switch/Recent Apps'),
  keyCodeMenu(82, 'Menu'),
  keyCodeSearch(84, 'Search'),
  
  // Volume Keys
  keyCodeVolumeUp(24, 'Volume Up'),
  keyCodeVolumeDown(25, 'Volume Down'),
  keyCodeVolumeMute(164, 'Volume Mute'),
  
  // Media Keys
  keyCodeMediaPlayPause(85, 'Media Play/Pause'),
  keyCodeMediaStop(86, 'Media Stop'),
  keyCodeMediaNext(87, 'Media Next'),
  keyCodeMediaPrevious(88, 'Media Previous'),
  keyCodeMediaRewind(89, 'Media Rewind'),
  keyCodeMediaFastForward(90, 'Media Fast Forward'),
  
  // Channel Keys
  keyCodeChannelUp(166, 'Channel Up'),
  keyCodeChannelDown(167, 'Channel Down'),
  
  // Number Keys
  keyCode0(7, 'Number 0'),
  keyCode1(8, 'Number 1'),
  keyCode2(9, 'Number 2'),
  keyCode3(10, 'Number 3'),
  keyCode4(11, 'Number 4'),
  keyCode5(12, 'Number 5'),
  keyCode6(13, 'Number 6'),
  keyCode7(14, 'Number 7'),
  keyCode8(15, 'Number 8'),
  keyCode9(16, 'Number 9'),
  
  // Special Function Keys
  keyCodeEnter(66, 'Enter'),
  keyCodeDel(67, 'Delete/Backspace'),
  keyCodeSpace(62, 'Space'),
  keyCodeTab(61, 'Tab'),
  keyCodeEscape(111, 'Escape');

  const KeyCodes(this.code, this.description);
  
  final int code;
  final String description;
  
  /// Returns the ADB input command for this keycode
  String get inputCommand => 'input keyevent $code';
}
