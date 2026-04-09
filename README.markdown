# Yelloscope #

My fork of [Syscomp Design's](https://www.syscompdesign.com/) software for their USB Oscilloscopes.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Yelloscope](#yelloscope)
    - [Firmware hex files](#firmware-hex-files)
    - [Sample waveforms for the arbitrary waveform generator](#sample-waveforms-for-the-arbitrary-waveform-generator)
    - [Change log](#change-log)
        - [Release version 1.0.0 for Linux](#release-version-100-for-linux)

<!-- markdown-toc end -->

## Firmware hex files ##

Each supported device (CGM-101, CGR-201, and SIG-101) contains a
microcontroller and an FPGA.  Firmware for the individual
microcontrollers is in `src/Firmware`.

## Sample waveforms for the arbitrary waveform generator ##

Look for waveform examples in `doc/example_waveforms`.

