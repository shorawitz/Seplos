import serial, codecs, time
from operator import itemgetter

rs485_device = "/dev/ttyUSB0"
baud_rate = 9600

pack_settings = {
  'pack1': {
    'address': '00'
  }
}

"""
pack_settings = {
  'pack1': {
    'address': '01'
  },
  'pack2': {
    'address': '02'
  },
  'pack3': {
    'address': '03'
  },
  'pack4': {
    'address': '04'
  },
  'pack5': {
    'address': '05'
  },
  'pack6': {
    'address': '06'
  },
  'pack7': {
    'address': '07'
  },
  'pack8': {
    'address': '08'
  }
}
"""

def convert_address(address):
  send = '20' + address + '4642E00201' 
  sum = 0

  for i in range(len(send)):
    sum += ord(send[i])    

  bwsum = ~sum + 1
  hexsum = format(bwsum, '04X').zfill(4)
  hexbwsum = hex((bwsum + (1 << 16)) % (1 << 16)).lstrip('0x')
  cmd = '~' + send + hexbwsum.upper() + '\r\n'
 
  return cmd

def query_seplos(device, baud):
  print(device,baud)
  ser = serial.Serial(device, baud)

  if ser.is_open:

    pack_data = {}
    pack_temps = {}

    for pack in pack_settings:
      offset = 19

      send = convert_address(pack_settings[pack]['address'])
      send_data = str.encode(send)
      ser.write(send_data)
      time.sleep(0.5)

      len_return_data = ser.inWaiting()
      if len_return_data == 0:
        continue
      
      return_data = ser.read(len_return_data)
      str_return_data = str(return_data.hex())
      str_bytes = bytes(str_return_data, encoding='utf-8')
      binary_string = codecs.decode(str_bytes, "hex")
      converted = str(binary_string, 'utf-8')

      ##
      # Get cell information
      ncell = int(converted[17:19],16)
      cell_voltages = {}

      for cell in range(1, ncell+1):
        cell_voltage = float(int(converted[offset:offset+4],16)/1000)
        offset += 4
        cell_voltages["cell"+str(cell)] = cell_voltage

      pack_data[pack] = cell_voltages

      low_cell = dict(sorted(cell_voltages.items(), key = itemgetter(1), reverse = False)[:1])
      (lkey, lval) = low_cell.popitem()
      high_cell = dict(sorted(cell_voltages.items(), key = itemgetter(1), reverse = True)[:1])
      (hkey, hval) = high_cell.popitem()

      pack_data[pack]['low_cell_id'] = lkey
      pack_data[pack]['low_cell_voltage'] = lval
      pack_data[pack]['high_cell_id'] = hkey
      pack_data[pack]['high_cell_voltage'] = hval


      ##
      # Get Temp information
      nprobes = int(converted[offset:offset+2],16)

      offset += 2
      for probe in range(1, nprobes+1):
        temp = float((int(converted[offset:offset+4],16) - 2731) / 10)
        offset += 4

        if probe <= 4:
          pack_temps["temp"+str(probe)] = temp
        elif probe == 5:
          pack_temps["env_temp"] = temp
        else:
          pack_temps["pcb_temp"] = temp
          
      # Add temps to pack_data
      pack_data[pack].update(pack_temps)

      ##
      # Get Other information
      pack_current_raw = int(converted[offset:offset+4],16)

      if pack_current_raw > 32767:
        pack_current = float((pack_current_raw - 65536) / 100)
      else:
        pack_current = float(pack_current_raw / 100)
      offset += 4

      pack_voltage = float(int(converted[offset:offset+4],16) / 100)
      offset += 4

      pack_ah_available = float(int(converted[offset:offset+4],16) / 100)
      offset += 6

      pack_ah_total = float(int(converted[offset:offset+4],16) / 100)
      offset += 4

      pack_soc = float(int(converted[offset:offset+4],16) / 10)
      offset += 4

      pack_ah_rated = float(int(converted[offset:offset+4],16) / 100)
      offset += 4

      pack_cycles = int(converted[offset:offset+4],16)
      offset += 4

      pack_soh = float(int(converted[offset:offset+4],16) / 10)
      offset += 4

      pack_bus_voltage = float(int(converted[offset:offset+4],16) / 100)
      offset += 4

      # Add other pack information to pack_data
      pack_data[pack].update({"pack_current":pack_current,"pack_voltage":pack_voltage,"pack_ah_available":pack_ah_available,"pack_ah_total":pack_ah_total,"pack_soc":pack_soc,"pack_ah_rated":pack_ah_rated,"pack_cycles":pack_cycles,"pack_soh":pack_soh,"pack_bus_voltage":pack_bus_voltage})

      

    return pack_data

  else:
    print("port open failed")

seplos_data = query_seplos(rs485_device, baud_rate)

print(seplos_data)
