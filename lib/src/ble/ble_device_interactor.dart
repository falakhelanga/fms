import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart' as uuid;

class BleDeviceInteractor {
  BleDeviceInteractor({
    required Future<List<DiscoveredService>> Function(String deviceId)
        bleDiscoverServices,
    // required Future<void> Function(Uint8List value)
    //     advertisePayload,
    required Future<List<int>> Function(QualifiedCharacteristic characteristic)
        readCharacteristic,
    required Future<void> Function(QualifiedCharacteristic characteristic,
            {required List<int> value})
        writeWithResponse,
    required Future<void> Function(QualifiedCharacteristic characteristic,
            {required List<int> value})
        writeWithOutResponse,
    required void Function(String message) logMessage,
    required Stream<List<int>> Function(QualifiedCharacteristic characteristic)
        subscribeToCharacteristic,
  })  : _bleDiscoverServices = bleDiscoverServices,
        // _advertisePayload = advertisePayload,
        _readCharacteristic = readCharacteristic,
        _writeWithResponse = writeWithResponse,
        _writeWithoutResponse = writeWithOutResponse,
        _subScribeToCharacteristic = subscribeToCharacteristic,
        _logMessage = logMessage;

  final Future<List<DiscoveredService>> Function(String deviceId)
      _bleDiscoverServices;

  // final Future<void> Function({required Uint8List value}) _advertisePayload;

  final Future<List<int>> Function(QualifiedCharacteristic characteristic)
      _readCharacteristic;

  final Future<void> Function(QualifiedCharacteristic characteristic,
      {required List<int> value}) _writeWithResponse;

  final Future<void> Function(QualifiedCharacteristic characteristic,
      {required List<int> value}) _writeWithoutResponse;

  final Stream<List<int>> Function(QualifiedCharacteristic characteristic)
      _subScribeToCharacteristic;

  final void Function(String message) _logMessage;

  Future<List<DiscoveredService>> discoverServices(String deviceId) async {
    try {
      _logMessage('Start discovering services for: $deviceId');
      final result = await _bleDiscoverServices(deviceId);
      _logMessage('Discovering services finished');
      return result;
    } on Exception catch (e) {
      _logMessage('Error occured when discovering services: $e');
      rethrow;
    }
  }

  Future<List<int>> readCharacteristic(
      QualifiedCharacteristic characteristic) async {
    try {
      final result = await _readCharacteristic(characteristic);

      _logMessage('Read ${characteristic.characteristicId}: value = $result');
      return result;
    } on Exception catch (e, s) {
      _logMessage(
        'Error occured when reading ${characteristic.characteristicId} : $e',
      );
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }

  Future<void> writeCharacterisiticWithResponse(
      QualifiedCharacteristic characteristic, List<int> value) async {
    try {
      _logMessage(
          'Write with response value : $value to ${characteristic.characteristicId}');
      await _writeWithResponse(characteristic, value: value);
    } on Exception catch (e, s) {
      _logMessage(
        'Error occured when writing ${characteristic.characteristicId} : $e',
      );
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }

  Future<void> writeCharacterisiticWithoutResponse(
      QualifiedCharacteristic characteristic, List<int> value) async {
    try {
      await _writeWithoutResponse(characteristic, value: value);
      _logMessage(
          'Write without response value: $value to ${characteristic.characteristicId}');
    } on Exception catch (e, s) {
      _logMessage(
        'Error occured when writing ${characteristic.characteristicId} : $e',
      );
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }

  Stream<List<int>> subScribeToCharacteristic(
      QualifiedCharacteristic characteristic) {
    _logMessage('Subscribing to: ${characteristic.characteristicId} ');
    return _subScribeToCharacteristic(characteristic);
  }

  // METHOD FOR PHONE TO ADVERTISE LIKE A BLE PERIPHERAL DEVICE
  Future<void> advertisePayload(
      Uint8List value) async {
    try {
      // Finder manufacturer specific data
      final manufacturerData = Uint8List.fromList([0xFF]);

      // Create AdvertiseData
      final AdvertiseData advertiseData = AdvertiseData(
        //serviceDataUuid: 'd973f2e0-b19e-11e0-9e96-0800200c9a66', // UUID Finder Service
        //manufacturerData: manufacturerData, // Finder manufacturer specific data = 0xFF
        manufacturerId: 1377,  //0x05 0x61 to 0d1377
        manufacturerData: value,
        includeDeviceName: false,
      );

      // Check if advertising is in progress and stop it if necessary.
      if (await _blePeripheral.isAdvertising) {
        await _blePeripheral.stop();
      }

      // Start advertising with the provided AdvertiseData
      await _blePeripheral.start(advertiseData: advertiseData);
      _logMessage('Advertising command to device');

      // Stop advertising after x seconds
      await Future.delayed(Duration(seconds: 1));
      await _blePeripheral.stop();
      _logMessage('Advertising stopped');

    } catch (e) {
        print('Error sending command: $e');
    }
  }

  ////////////////////////////////////////////////
  // START OF FINDER BLE RELAY SERVICE COMMANDS //
  ////////////////////////////////////////////////

  // Create ble peripheral for advertising payloads
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  // Instance variable to store the relay counter
  int _counter = 0;

  // Convert byte array to string UUID
  String convertBytesToUuid(List<int> byteArray) {
    return uuid.Uuid.unparse(byteArray);
  }

  List<int> calculateTimerBytes(int seconds) {
    if (seconds >= 1 && seconds <= 58) {
      // Convert seconds to a single byte value
      return [seconds];
    } else if (seconds >= 60 && seconds <= 7200) {
      // Convert minutes to a single byte value
      return [(seconds ~/ 60) + 59];
    } else if (seconds >= 9000 && seconds <= 86400) {
      // Convert hours to a single byte value
      return [(seconds ~/ 3600) + 179];
    } else {
      throw ArgumentError('Invalid seconds value for timer: $seconds');
    }
  }

  Uint8List generateSecret(String deviceId) {
    // Split the deviceId string into segments using ':'
    List<String> segments = deviceId.split(':');

    // Convert each segment to an integer and create a Uint8List
    Uint8List deviceIdBytes = Uint8List.fromList(
      segments.map((segment) => int.parse(segment, radix: 16)).toList(),
    );

    // If deviceIdBytes.length is greater than 16, truncate it
    final truncatedBytes = deviceIdBytes.length > 16
        ? deviceIdBytes.sublist(deviceIdBytes.length - 16)
        : deviceIdBytes;

    final secret = Uint8List(16); // Limiting the variable to 16 bytes

    // Fill the initial bytes with 0xFF
    secret.fillRange(0, 16 - truncatedBytes.length, 0xFF);

    // Copy deviceIdBytes to the last bytes of the secret
    secret.setAll(16 - truncatedBytes.length, truncatedBytes);

    // Log generated secret
    // Convert payload to a hexadecimal string
    final secretHex = secret.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    //_logMessage('Secret used: $secretHex');

    return secret;
  }

  Uint8List encryptPayload(Uint8List payload, String deviceId) {
    // Split the deviceId string into segments using ':'
    List<String> segments = deviceId.split(':');

    // Convert each segment to an integer and create a Uint8List
    Uint8List deviceIdBytes = Uint8List.fromList(
      segments.map((segment) => int.parse(segment, radix: 16)).toList(),
    );

    // If deviceIdBytes.length is greater than 16, truncate it
    final truncatedMacBytes = deviceIdBytes.length > 16
        ? deviceIdBytes.sublist(deviceIdBytes.length - 16)
        : deviceIdBytes;

    // Generate the IV (Initialization Vector) of 13 bytes
    //final hardwareMacAddress = deviceId.substring(deviceId.length - 12);
    final iv = Uint8List.fromList([
      ...truncatedMacBytes,
      (_counter >> 24) & 0xFF,
      (_counter >> 16) & 0xFF,
      (_counter >> 8) & 0xFF,
      _counter & 0xFF,
      0x00,
      0x00,
      0x00,
    ]);

    // Create AES cipher with CCM mode to generate HMAC
    final cipher = CCMBlockCipher(AESEngine());

    // Create AEAD parameters with secret key, mac size of 32 bits, iv, associated data.
    final params = AEADParameters(KeyParameter(generateSecret(deviceId)),32, iv, Uint8List(0));

    // Initialize cipher with encryption mode and parameters
    cipher.init(true, params);

    // Process Additional Authenticated Data (AadBytes)
    cipher.processAADBytes(payload, 0, payload.length);

    // Generate 4-byte MAC signature
    final signatureMac = Uint8List(4);
    cipher.doFinal(signatureMac, 0);

    // Log secret and signature used
    // Convert payload to a hexadecimal string
    // final ivHex = iv.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    // final signatureHex = signatureMac.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    //_logMessage('IV used: $ivHex');
    //_logMessage('Signature used: $signatureHex');

    // Return signature
    return Uint8List.fromList(signatureMac);
  }

  Future<void> writeSymmetricKey(String deviceId, bool isDeleteKey) async {
    /*   To completely configure a device you need to:
      1) press the button connected to the device
      2) send the master key (it is only accepted for 5 seconds)
      3) release the button
      4) send the configuration of the device, signed by the master key
    The commands should be sent to characteristic: d973f2e2-b19e-11e2-9e96-0800200c9a66   */

    // command = 0x50 for BLE manufacturer command to send key to device
    // command = 0x52 for BLE manufacturer command to delete key and restore to default settings
    final payload = Uint8List(32);

    //final serviceUuidBytes =        [0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe1,0xf2,0x73,0xd9];
    //final characteristicUuidBytes = [0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe2,0xf2,0x73,0xd9];
    //Byte order depends on little endian or big endian approach to programming language. UUID is reversed depending.
    final serviceUuidBytes =        "d973f2e0-b19e-11e0-9e96-0800200c9a66";
    final characteristicUuidBytes = "d973f2e2-b19e-11e2-9e96-0800200c9a66"; //Characteristic 1 - Commands


    // Byte 0: Command
    payload[0] = isDeleteKey ? 0x52 : 0x50;

    // Bytes 1-4: Counter
    payload[1] = (_counter >> 24) & 0xFF;
    payload[2] = (_counter >> 16) & 0xFF;
    payload[3] = (_counter >> 8) & 0xFF;
    payload[4] = _counter & 0xFF;

    // Bytes 5-20: Symmetric Key
    if (isDeleteKey) {
      // For command 0x52 ("Delete and restore to default"), set Bytes 5-20 to 0x00
      payload.fillRange(5, 21, 0x00);
    } else {
      // For other commands, set Bytes 5-20 to the symmetric key
      payload.setAll(5, generateSecret(deviceId));
    }

    // Bytes 28-31: The command 0x50 ("Phone encryption pair key") does not use a signature
    // and the final 4 bytes of the payload should be set to 0x00 0x00 0x00 0x00
    payload.setAll(28, [0x00, 0x00, 0x00, 0x00]);

    // Convert payload to a hexadecimal string
    final payloadHex = payload.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');

    // Log the payload as a string
    //_logMessage('Payload: $payloadHex');
    _logMessage('Counter: $_counter');

     final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: Uuid.parse(serviceUuidBytes),
      characteristicId: Uuid.parse(characteristicUuidBytes),
    );

    try {
      await _writeWithResponse(characteristic, value: payload);
      _logMessage('Symmetric key sent successfully');

      // Set the counter to 1 after a successful write. After you set the master key, the counter on the device is set to 0 so the next
      // command will strictly need to have the counter set to 1 (or greater) and be signed by the master key.
      _counter = 1;
    } on Exception catch (e, s) {
      _logMessage('Error sending symmetric key: $e');
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }

  Future<void> setDeviceFunction(String deviceId, bool isRiFunction, int secondsT1, int secondsT2) async {
    final serviceUuidBytes =        "d973f2e0-b19e-11e0-9e96-0800200c9a66";
    //final characteristicUuidBytes = "d973f2e2-b19e-11e2-9e96-0800200c9a66"; //Characteristic 1 - Commands
    final characteristicUuidBytes = "d973f2e3-b19e-11e2-9e96-0800200c9a66"; //Characteristic 2 - Send settings


    // Payload construction
    final payload28bytes = Uint8List.fromList([
      0x01,
      (_counter >> 24) & 0xFF,
      (_counter >> 16) & 0xFF,
      (_counter >> 8) & 0xFF,
      _counter & 0xFF,
      isRiFunction ? 0xA2 : 0xA4,
      ...calculateTimerBytes(secondsT1), // Timer T1 starting at byte 6
      ...calculateTimerBytes(secondsT2), // Timer T2 starting at byte 7
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]);

    // Convert payload to a hexadecimal string
    final payload28bytesHex = payload28bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');

    // Log the payload as a string
    _logMessage('Set function command payload: $payload28bytesHex');

    // Encrypt the payload
    final encryptedPayload32bytes = encryptPayload(payload28bytes, deviceId);

    // Log the encrypted payload
    final encryptedPayload32bytesHex = encryptedPayload32bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('');
    _logMessage('Set function command signed payload: $encryptedPayload32bytesHex');

    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: Uuid.parse(serviceUuidBytes),
      characteristicId: Uuid.parse(characteristicUuidBytes),
    );

    try {
      // Send the encrypted payload to the device
      await _writeWithResponse(characteristic, value: encryptedPayload32bytes);
      _logMessage('Set function command sent successfully');

      // Increment the counter after a successful command send
      _counter+2;
      _logMessage('Counter: $_counter');

    } on Exception catch (e, s) {
      _logMessage('Error setting device function: $e');
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }

  bool currentButtonState = false;
  bool newButtonState = false;

  Future<void> sendCommandToDevice(String deviceId) async {
    // final serviceUuidBytes =        "d973f2e0-b19e-11e0-9e96-0800200c9a66";
    // final characteristicUuidBytes = "d973f2e2-b19e-11e2-9e96-0800200c9a66"; //Characteristic 1 - Commands
    // final characteristicUuidBytes = "d973f2e3-b19e-11e2-9e96-0800200c9a66"; //Characteristic 2 - Send settings

    final fixedIdCode = [0x0C, 0xFF, 0x61, 0x05];

    //Toggle the button every time command is sent
    currentButtonState = newButtonState; //(_counter & 0x01) == 0x01;
    newButtonState = true; //!currentButtonState; //true;

    // Full payload construction including payload length (0x0C) and manufacturer ID (0x05 0x61 or 0d1377) for encryption
    final payload9bytes = Uint8List.fromList([
      ...fixedIdCode,
      (_counter >> 24) & 0xFF,
      (_counter >> 16) & 0xFF,
      (_counter >> 8) & 0xFF,
      _counter & 0xFF,
      ((newButtonState ? 0x01 : 0x00) << 0) |
      (0x01 << 1) |
      (0x00 << 2) |
      (0x00 << 3) |
      (0x00 << 4) |
      (0x00 << 5) |
      (0x00 << 6) |
      (0x00 << 7),
    ]);

    // Payload construction for send command. BLE Peripheral package adds payload length (0x0C) and manufacturer ID (0x05 0x61 or 0d1377)
    final payload5bytes = Uint8List.fromList([
      (_counter >> 24) & 0xFF,
      (_counter >> 16) & 0xFF,
      (_counter >> 8) & 0xFF,
      _counter & 0xFF,
      ((newButtonState ? 0x01 : 0x00) << 0) |
      (0x01 << 1) |
      (0x00 << 2) |
      (0x00 << 3) |
      (0x00 << 4) |
      (0x00 << 5) |
      (0x00 << 6) |
      (0x00 << 7),
    ]);

    // Encrypt the full payload
    final encryptedSignature = encryptPayload(payload9bytes, deviceId);
    final encryptedPayload = Uint8List.fromList(payload5bytes + encryptedSignature); //send payload without payload length and manufacturer ID 0x05 0x61 as plugin prepends these.

    // Log the full payload
    final payloadHex = payload9bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('');
    _logMessage('Button command payload: $payloadHex');

    try {
      // Broadcast the encrypted payload to all nearby devices.
      // Devices which decrypt successfully with the deviceID specific signature and valid cyrptographic counter value will react.
      await advertisePayload(encryptedPayload);
      _logMessage('Payload successfully advertised');

      // Increment the counter after a successful command send
      _counter = _counter+2;
      _logMessage('Counter: $_counter');

    } on Exception catch (e, s) {
      _logMessage('Error advertising command: $e');
      // ignore: avoid_print
      print(s);
      rethrow;
    }

    // final characteristic = QualifiedCharacteristic(
    //   deviceId: deviceId,
    //   serviceId: Uuid.parse(serviceUuidBytes),
    //   characteristicId: Uuid.parse(characteristicUuidBytes),
    // );
    //
    // try {
    //   await _writeWithoutResponse(characteristic, value: encryptedPayload13bytes);
    //   _logMessage('Button command advertised successfully');
    //
    // } on Exception catch (e, s) {
    //   _logMessage('Error sending command: $e');
    //   // ignore: avoid_print
    //   print(s);
    //   rethrow;
    // }
  }

  Future<void> wakeUpDeviceAdvertising(
      String deviceId,
      bool isConnectable,
      int advertisingTimeMultiplier,
      bool isBroadcastToAll,
      ) async {
    final fixedIdCode = [0x0C, 0xFF, 0x61, 0x05];
    final type = isBroadcastToAll ? [0xFF, 0xFF, 0xFF, 0xFF] : deviceId.substring(deviceId.length - 4).codeUnits;
    final timeByte = (isConnectable ? 0x00 : 0x80) | (advertisingTimeMultiplier & 0x7F);
    final signature = [0x00, 0x00, 0x00, 0x00];

    // Full payload construction including payload length (0x0C) and manufacturer ID (0x05 0x61 or 0d1377) for encryption
    final payload13bytes = Uint8List.fromList([
      ...fixedIdCode,
      ...type,
      timeByte,
      ...signature,
    ]);

    // Convert payload to a hexadecimal string
    final payloadHex = payload13bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');

    // Log the payload as a string
    _logMessage('Advertising wake-up payload: $payloadHex');

    try {
      // Broadcast the encrypted payload to all nearby devices.
      // Devices which decrypt successfully with the deviceID specific signature and valid cyrptographic counter value will react.
      await advertisePayload(payload13bytes);
      _logMessage('Payload successfully advertised');

      // Increment the counter after a successful command send
      _counter = _counter+2;
      _logMessage('Counter: $_counter');

    } on Exception catch (e, s) {
      _logMessage('Error advertising command: $e');
      // ignore: avoid_print
      print(s);
      rethrow;
    }

    // final characteristic = QualifiedCharacteristic(
    //   deviceId: deviceId,
    //   serviceId: Uuid.parse(serviceUuidBytes),
    //   characteristicId: Uuid.parse(characteristicUuidBytes),
    // );
    //
    // try {
    //   await _writeWithoutResponse(characteristic, value: payload);
    //   _logMessage('Advertising wake-up command sent successfully');
    //
    //   // Increment the counter after a successful command send
    //   _counter++;
    //   _logMessage('Counter: $_counter');
    //
    // } on Exception catch (e, s) {
    //   _logMessage('Error sending wake-up command: $e');
    //   // ignore: avoid_print
    //   print(s);
    //   rethrow;
    // }
  }

  // Parse the advertising payload
  void parseAdvertisingPayload(List<int> payload) {
    if (payload.length != 22) {
      _logMessage('Invalid payload length');
      return;
    }

    final payloadLength = payload[0];
    final nextFieldLength = payload[1];
    final bleManufacturerSpecificData = payload[2];
    final deviceMacAddress = payload.sublist(3, 9);
    final channel1Function = payload[9];
    final channel2Function = payload[10];
    final relayStatus = (payload[11] & 0x01) == 0x01; // Bit 0
    final buttonStatus = (payload[12] & 0x01) == 0x01; // Bit 0
    final counter = (payload[13] << 8) | payload[14]; //Note that this is not the cyrptographic counter using for encryption
    final fwVersion = payload[15];
    final ack = payload.sublist(16, 20);
    final nextFieldLength2 = payload[20];
    final bleFlagByte = payload[21];
    final flag = payload[22];

    // Now you can use the parsed values as needed
    _logMessage('Parsed Advertising Payload:');
    _logMessage('Payload Length: $payloadLength');
    _logMessage('Next Field Length: $nextFieldLength');
    _logMessage('BLE Manufacturer Specific Data: $bleManufacturerSpecificData');
    _logMessage('Device MAC Address: $deviceMacAddress');
    _logMessage('Channel 1 Function: $channel1Function');
    _logMessage('Channel 2 Function: $channel2Function');
    _logMessage('Relay Status: $relayStatus');
    _logMessage('Button Status: $buttonStatus');
    _logMessage('Counter: $counter');
    _logMessage('FW Version: $fwVersion');
    _logMessage('ACK: $ack');
    _logMessage('Next Field Length 2: $nextFieldLength2');
    _logMessage('BLE Flag Byte: $bleFlagByte');
    _logMessage('Flag: $flag');
  }
}
