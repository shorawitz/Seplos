# Seplos
Seplos BMS

Using _query_seplos.sh_ as a base, the **seplos.py** file was created in order to integrate with Flask to provide an API for querying any/all Seplos BMS' connected to a RS-485/USB interface.

# Home Assistant
I've included an example config for Home Asssistant: https://www.home-assistant.io/ in case anyone would like to replicate my setup: https://www.youtube.com/watch?v=SrlevyygR1o

# Hardware
Raspberry Pi4 (or any computer with available USB port)
Waveshare USB to RS485 adapter
Modified Cat5 ethernet cable pinout:
  A:   2 OR 7 (orange OR white brown)
  GND: 3 OR 6 (white green OR green)
  B:   1 OR 8 (white orange OR brown)
