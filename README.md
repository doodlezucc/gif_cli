# GIF_CLI

Convert image sequences into animated GIFs!

![Demo video (which in itself is also a GIF)](https://github.com/doodlezucc/gif_cli/blob/master/demo.gif?raw=true)

*Demonstratinng gif_cli by turning an excerpt from
["Harvey" by Her's](https://www.youtube.com/watch?v=8gnSgWRCV1A)
into a GIF*


## Installing

**Please note that gif_cli requires [ffmpeg](https://www.ffmpeg.org/) to be installed
on your machine.**

### Option 1: pub package
[Dart](https://dart.dev/get-dart) users can simply run `dart pub global activate gif_cli`
to install the package from [pub.dev](https://pub.dev/packages/gif_cli).

### Option 2: Standalone
Download an executable from [Releases](https://github.com/doodlezucc/gif_cli/releases)
and add it to your PATH environment variable.


## Running

Launch your terminal of choice, navigate to a directory that contains image sequences
and run `gif`. The CLI will then guide you through the conversion process, as shown in
the demo above.


## Building

Once you have [Dart](https://dart.dev/get-dart) installed, run
`dart compile exe bin/gif_cli.dart`
in the project directory to compile gif_cli into a standalone,
architecture-specific executable file.
