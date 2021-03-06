Copyright Notice
================

Copyright (c) 2009-2010 by The Stig. All rights reserved. 

Contact
=======

The Stig <the.stig.dev@gmail.com>

Description
===========

A simple project that builds an Acorn 2.0-compatible plugin to load Painter RIFF files.

Requirements
============

Requires Corel Painter 11 or Corel Painter Sketch Pad, as these applications contain the proper frameworks (Renderer and RiffIO) to read Painter files. By default, the frameworks are located in /Applications/Corel Painter 11/Corel Painter 11.app/Contents/Frameworks/, but you may have to adjust according to your installation.

Will probably work with Corel Painter X as well, as it also includes a (slightly less advanced) version of the same frameworks.

Building and Installing
=======================

1. Open the Xcode project, update the path to the Painter frameworks (if necessary) and build the Release target.
2. Copy the resulting "TSRIFFLoader.acplugin" to ~/Library/Application Support/Acorn/Plug-In.
3. Re-launch Acorn. You should now be able to open RIFF files in Acorn, with all layers separated and in their proper place.

Architecture
============

Everything is Intel-only since the Acorn Import API appeared in Acorn 2.0, which is Snow Leopard-only (hence, Intel-only).

Since the Corel frameworks are 32-bit only at the moment, this plugin contains a 32-bit helper application to decode RIFF files into their separate layers.
These layers are stored in png files in a temporary location, and all the relevant metadata is output as XML to standard output.

All that the plugin does is launch the helper app, parse the XML metadata and load each png file in turn, inserting it as an ACLayer.

