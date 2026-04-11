# Yelloscope #

My fork of Syscomp Design's (defunct) software for their USB Oscilloscopes.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Yelloscope](#yelloscope)
  - [Documentation](#documentation)
  - [Firmware hex files](#firmware-hex-files)
  - [Sample waveforms for the arbitrary waveform generator](#sample-waveforms-for-the-arbitrary-waveform-generator)

<!-- markdown-toc end -->

## Documentation ##

The CGR-201 operating manual is [here](doc/CGR-201-Manual.pdf).
CGR-201 commands are documented [here](doc/CGR-201-Command-List.pdf).

## Firmware hex files ##

Each supported device (CGM-101, CGR-201, and SIG-101) contains a
microcontroller and an FPGA.  Firmware for the individual
microcontrollers is in `src/Firmware`.

## Sample waveforms for the arbitrary waveform generator ##

Look for waveform examples in `doc/example_waveforms`.

