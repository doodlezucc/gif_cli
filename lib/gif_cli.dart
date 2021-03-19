import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;

final _regexDigits = RegExp(r'[0-9]');
final _regexLastDigits = RegExp(r'(\d+)(?!.*\d)');

final _imageExtensions = ['png', 'jpg'];

/// Forwards lines of a ffmpeg process to the console and waits for it finish.
///
/// [printFrames] - Makes sure that every progress update is printed.
///
/// [printAll] - Prints every single line of [process.stderr] (ffmpeg's output
/// stream).
Future<void> debugFFmpegProcess(
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

/// A container of indexed image files.
class ImageSequence {
  final frames = SplayTreeMap<int, File>();
  double inputFps = 30;
  double get outputFps => toValidFps(inputFps);

  int _digits = 0;
  final String prefix;
  final String suffix;

  /// The first frame's index.
  int get start => frames.firstKey();

  /// The last frame's index.
  int get end => frames.lastKey();

  /// [prefix] - What stands before the index of each frame.
  ///
  /// [suffix] - What stands after the index of each frame.
  ImageSequence(this.prefix, this.suffix);

  /// Returns `true` if every frame from [start] to [end] is present.
  bool get isComplete {
    for (var i = start; i <= end; i++) {
      if (!frames.containsKey(i)) {
        return false;
      }
    }
    return true;
  }

  /// Returns `true` if the sequence consists of 2 or more frames.
  bool get makesSense => frames.length > 1;

  List<String> get _arguments => [
        ..._defaultArguments,
        '-start_number',
        '$start',
        '-r',
        '$inputFps',
        '-i',
        '$prefix%${_digits.toString().padLeft(2, '0')}d.png',
      ];

  List<String> get _defaultArguments => ['-y', '-hide_banner'];

  /// Inserts [f] at its name embedded index.
  void addFrame(File f) {
    var fileName = path.basename(f.path);
    var frameString = _getDigits(fileName);
    var frame = int.parse(frameString);
    var newDigs = frameString.length;

    if (_digits > 0 && _digits != newDigs) {
      print('Warning: changing digits');
    }
    _digits = newDigs;

    frames[frame] = f;
  }

  /// Generates a color palette image based on all frames.
  Future<File> generatePalette() async {
    var palettePath = 'gif_palette.png';

    var process = await Process.start('ffmpeg', [
      ..._arguments,
      '-filter_complex',
      'scale=-1:-1:flags=lanczos,palettegen',
      palettePath,
    ]);

    await debugFFmpegProcess(process, printFrames: false);

    print('Generated palette');

    return File(palettePath);
  }

  /// Starts a ffmpeg process to convert all frames
  /// into a single animated GIF.
  Future<File> convertToGif(File output) async {
    //var inputs = <String>[];
    //frames.values.forEach((e) => inputs.addAll(['-i', e.path]));

    var palette = await generatePalette();

    await output.create(recursive: true);

    var args = [
      ..._arguments,
      '-i',
      palette.path,
      '-filter_complex',
      'fps=$outputFps,scale=-1:-1:flags=lanczos[x];[x][1:v]paletteuse',
      output.path,
    ];

    var process = await Process.start('ffmpeg', args);
    await debugFFmpegProcess(process);

    await palette.delete();

    return output;
  }

  @override
  String toString() =>
      '"${path.basename(prefix + '[$start-$end]' + suffix)}"' +
      (!isComplete ? ' (incomplete!)' : '');
}

String _getDigits(String filename) {
  return _regexLastDigits.stringMatch(filename);
}

/// Collects files from [dir] and returns all matched image sequences.
/// Optionally recurses into sub-directories.
Future<List<ImageSequence>> findSequences(Directory dir,
    {bool recursive = false}) async {
  var files = <File>[];
  var completer = Completer<List<File>>();
  var fileStream = dir.list(recursive: recursive);
  fileStream.listen(
    (file) {
      if (file is File) files.add(file);
    },
    onDone: () => completer.complete(files),
  );
  return sequencesFromFiles(await completer.future);
}

/// Analyzes the given [files] for images with similar file names
/// and returns all sequences with 2 or more frames.
///
/// Image sequences are matched by comparing the start of each file name.
///
/// ```
/// | a00.png, b1.png, foobar00001.jpg, |
/// | a01.png,         foobar00002.jpg, |
/// | a02.png                           |
///
///   =>  [a%.png, foobar%.jpg]
/// ```
List<ImageSequence> sequencesFromFiles(List<File> files) {
  var stems = <String, ImageSequence>{};
  for (var file in files) {
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
  return stems.values.where((seq) => seq.makesSense).toList();
}
