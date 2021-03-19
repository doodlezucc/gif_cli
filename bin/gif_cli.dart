import 'dart:io';

import 'package:gif_cli/gif_cli.dart' as gif_cli;
import 'package:path/path.dart';
import 'package:prompts/prompts.dart' as prompts;

void main(List<String> arguments) async {
  var sequences = await gif_cli.findSequences(Directory.current);
  if (sequences.isEmpty) {
    print('No image sequences found!');
    return exit(1);
  }

  var seq = sequences[0];
  if (sequences.length > 1) {
    seq = prompts.choose('Found ${sequences.length} image sequences', sequences,
        color: false, prompt: 'Enter your choice:');
  } else {
    print('Found $seq');
  }

  if (!seq.isComplete) {
    print('Incomplete sequences are not supported yet.');
    exit(2);
  }

  seq.inputFps = prompts.getDouble('FPS', defaultsTo: 30, color: false);

  //var reverse = prompts.getBool('Reverse', color: false, defaultsTo: false);

  var output = prompts.get('Output',
      color: false,
      defaultsTo: basenameWithoutExtension(seq.prefix + 'anim' + seq.suffix));

  if (!output.endsWith('.gif')) {
    output = output + '.gif';
  }

  await seq.convertToGif(File(output));

  var showMeta = false;
  if (showMeta) {
    print('');
    await gif_cli.debugFFmpegProcess(
        await Process.start('ffprobe', [output, '-hide_banner']),
        printAll: true);
  }

  print('Done!');
}
