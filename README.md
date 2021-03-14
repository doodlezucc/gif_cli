# GIF_CLI

Convert image sequences into animated GIFs!

Download an executable, maybe even write it to your PATH environment variable,
then run `gif` inside a directory that contains image sequences.

**Please note** that gif_cli requires [ffmpeg](https://www.ffmpeg.org/) to be installed
on your machine.

## Building

Once you have [Dart](https://dart.dev/get-dart) installed, run
`dart compile exe bin/gif_cli.dart`
in the project directory to compile gif_cli into a standalone, architecture-specific executable file.