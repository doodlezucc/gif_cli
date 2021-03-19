import 'dart:io';

import 'package:gif_cli/gif_cli.dart' as gif;

// Although gif_cli is meant to be used as a CLI, you could also use
// it in your own Dart app as shown in this example.

// There's a very simple 7 frame animation inside the example/frames directory.
// It was rendered as a sequence of PNG images because Blender (the software
// used to produce the animation) doesn't export to GIF.
// Sounds like a perfect use case.

void main(List<String> args) async {
  var framesDir = Directory('example/frames');
  var sequences = await gif.findSequences(framesDir);

  // There should be only a single sequence,
  // as all frames share the same prefix and suffix ("cube" ... ".png").
  var cubeSequence = sequences.first;

  // Set the image sequence's designated framerate.
  cubeSequence.inputFps = 8;

  var output = await cubeSequence.convertToGif(File('example/cube.gif'));

  print('Converted to "${output.path}"');
}
