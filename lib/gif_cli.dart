import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;

final _regexDigits = RegExp(r'[0-9]');
final _regexLastDigits = RegExp(r'(\d+)(?!.*\d)');

final _imageExtensions = ['png', 'jpg'];

Future<void> finishFFmpeg(
  Process process, {
  bool printFrames = true,
  bool printAll = false,
}) async {
  var completer = Completer();

  process.stderr.listen(
    (data) {
      var msg = utf8.decode(data).trim();
      if (printAll) {
        print(msg);
      } else if (printFrames && msg.startsWith('frame')) {
        print(msg.split('\n')[0]);
      }
    },
    onDone: () => completer.complete(),
  );

  return await completer.future;
}

/// GIFs can only have a maximum framerate of 50
/// when exporting via ffmpeg.
double toValidFps(double fps) {
  return math.min(fps, 50);
}

class ImageSequence {
  var frames = SplayTreeMap<int, File>();
  double inputFps = 120;
  double get outputFps => toValidFps(inputFps);

  int digits = 0;
  final String prefix;
  final String suffix;

  int get start => frames.firstKey();
  int get end => frames.lastKey();

  ImageSequence(this.prefix, this.suffix);

  bool get isComplete {
    for (var i = start; i <= end; i++) {
      if (!frames.containsKey(i)) {
        return false;
      }
    }
    return true;
  }

  bool get makesSense => frames.length > 1;

  @override
  String toString() =>
      '"${path.basename(prefix + '[$start-$end]' + suffix)}"' +
      (!isComplete ? ' (incomplete!)' : '');

  void addFrame(File f) {
    var fileName = path.basename(f.path);
    var frameString = _getDigits(fileName);
    var frame = int.parse(frameString);
    var newDigs = frameString.length;

    if (digits > 0 && digits != newDigs) {
      print('Warning: changing digits');
    }
    digits = newDigs;

    frames[frame] = f;
  }

  List<String> get arguments => [
        ...defaultArguments,
        '-start_number',
        '$start',
        '-r',
        '$inputFps',
        '-i',
        '$prefix%${digits.toString().padLeft(2, '0')}d.png',
      ];

  List<String> get defaultArguments => ['-y', '-hide_banner'];

  Future<File> generatePalette() async {
    var palettePath = 'gif_palette.png';

    var process = await Process.start('ffmpeg', [
      ...arguments,
      '-filter_complex',
      'scale=-1:-1:flags=lanczos,palettegen',
      palettePath,
    ]);

    await finishFFmpeg(process, printFrames: false);

    print('Generated palette');

    return File(palettePath);
  }

  Future<File> convertToGif(File output) async {
    //var inputs = <String>[];
    //frames.values.forEach((e) => inputs.addAll(['-i', e.path]));

    var palette = await generatePalette();

    await output.create(recursive: true);

    var args = [
      ...arguments,
      '-i',
      palette.path,
      '-filter_complex',
      'fps=$outputFps,scale=-1:-1:flags=lanczos[x];[x][1:v]paletteuse',
      output.path,
    ];

    var process = await Process.start('ffmpeg', args);
    await finishFFmpeg(process);

    await palette.delete();

    return output;
  }
}

String _getDigits(String filename) {
  return _regexLastDigits.stringMatch(filename);
}

Future<List<ImageSequence>> findSequences(Directory dir,
    {bool recursive = false}) async {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: recursive);
  lister.listen((file) => files.add(file),
      // should also register onError
      onDone: () => completer.complete(files));
  return sequencesFromFiles(await completer.future);
}

List<ImageSequence> sequencesFromFiles(List<FileSystemEntity> files) {
  var stems = <String, ImageSequence>{};
  for (var file in files) {
    if (file is File) {
      var fp = file.path;

      if (_imageExtensions.any((ext) => fp.endsWith('.$ext'))) {
        if (path.basename(fp).contains(_regexDigits)) {
          var prefix = fp.substring(0, fp.indexOf(_regexLastDigits));
          stems
              .putIfAbsent(
                  prefix,
                  () => ImageSequence(
                      prefix, fp.substring(fp.lastIndexOf(_regexDigits) + 1)))
              .addFrame(file);
        }
      }
    }
  }
  return stems.values.where((seq) => seq.makesSense).toList();
}
