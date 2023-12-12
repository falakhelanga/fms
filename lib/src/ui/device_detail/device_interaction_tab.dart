import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_reactive_ble_example/src/ble/ble_device_connector.dart';
import 'package:flutter_reactive_ble_example/src/ble/ble_device_interactor.dart';
import 'package:functional_data/functional_data.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'characteristic_interaction_dialog.dart';

part 'device_interaction_tab.g.dart';
//ignore_for_file: annotate_overrides

class DeviceInteractionTab extends StatelessWidget {
  final DiscoveredDevice device;

  const DeviceInteractionTab({
    required this.device,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      Consumer3<BleDeviceConnector, ConnectionStateUpdate, BleDeviceInteractor>(
        builder: (_, deviceConnector, connectionStateUpdate, interactor, __) =>
            _DeviceInteractionTab(
          viewModel: DeviceInteractionViewModel(
              deviceId: device.id,
              connectionStatus: connectionStateUpdate.connectionState,
              deviceConnector: deviceConnector,
              discoverServices: () => interactor.discoverServices(device.id)),
          interactor: interactor,
        ),
      );
}

@immutable
@FunctionalData()
class DeviceInteractionViewModel extends $DeviceInteractionViewModel {
  const DeviceInteractionViewModel({
    required this.deviceId,
    required this.connectionStatus,
    required this.deviceConnector,
    required this.discoverServices,
  });

  final String deviceId;
  final DeviceConnectionState connectionStatus;
  final BleDeviceConnector deviceConnector;
  @CustomEquality(Ignore())
  final Future<List<DiscoveredService>> Function() discoverServices;

  bool get deviceConnected =>
      connectionStatus == DeviceConnectionState.connected;

  void connect() {
    deviceConnector.connect(deviceId);
  }

  void disconnect() {
    deviceConnector.disconnect(deviceId);
  }
}

class _DeviceInteractionTab extends StatefulWidget {
  const _DeviceInteractionTab({
    required this.viewModel,
    required this.interactor,
    Key? key,
  }) : super(key: key);

  final DeviceInteractionViewModel viewModel;
  final BleDeviceInteractor interactor;

  @override
  _DeviceInteractionTabState createState() => _DeviceInteractionTabState();
}

class _DeviceInteractionTabState extends State<_DeviceInteractionTab> {
  late List<DiscoveredService> discoveredServices;

  @override
  void initState() {
    discoveredServices = [];
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> discoverServices() async {
    final result = await widget.viewModel.discoverServices();
    setState(() {
      discoveredServices = result;
    });
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate.fixed(
              [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      top: 8.0, bottom: 16.0, start: 16.0),
                  child: Text(
                    "ID: ${widget.viewModel.deviceId}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16.0),
                  child: Text(
                    "Status: ${widget.viewModel.connectionStatus}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: !widget.viewModel.deviceConnected
                            ? widget.viewModel.connect
                            : null,
                        child: const Text("Connect"),
                      ),
                      ElevatedButton(
                        onPressed: widget.viewModel.deviceConnected
                            ? widget.viewModel.disconnect
                            : null,
                        child: const Text("Disconnect"),
                      ),
                      ElevatedButton(
                        onPressed: widget.viewModel.deviceConnected
                            ? discoverServices
                            : null,
                        child: const Text("Discover Services"),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: widget.viewModel.deviceConnected
                            ? () {
                                widget.interactor.writeSymmetricKey(
                                    widget.viewModel.deviceId, false);
                                print("Writing symmetric key");
                              }
                            : null,
                        child: const Text("Key"),
                      ),
                      ElevatedButton(
                        onPressed: widget.viewModel.deviceConnected
                            ? () {
                                widget.interactor.setDeviceFunction(
                                    widget.viewModel.deviceId, true, 5, 5);
                                print("Writing device function settings");
                              }
                            : null,
                        child: const Text("Set"),
                      ),
                      ElevatedButton(
                        onPressed: !widget.viewModel.deviceConnected
                            ? () {
                                widget.interactor.sendCommandToDevice(
                                    widget.viewModel.deviceId);
                                print("Sending command to device");
                              }
                            : null,
                        child: const Text("Toggle"),
                      ),
                      ElevatedButton(
                        onPressed: !widget.viewModel.deviceConnected
                            ? () {
                                // widget.interactor.(widget.viewModel.deviceId, true, 3, true); // Wake-up advertising all devices for 30s (3x10s)
                                print("Waking up device advertising");
                              }
                            : null,
                        child: const Text("Wake-up"),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        // ElevatedButton(
                        //   onPressed: widget.viewModel.deviceConnected
                        //       ? subscribeToAdvertisingPayloads
                        //       : null,
                        //     //widget.interactor.subscribeToAdvertisingPayloads(widget.viewModel.deviceId);
                        //   child: const Text("Listen to advertising"),
                        // ),
                        ElevatedButton(
                          onPressed: widget.viewModel.deviceConnected
                              ? () {
                                  widget.interactor.writeSymmetricKey(
                                      widget.viewModel.deviceId, true);
                                  print("Delete key and reset device");
                                }
                              : null,
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.red),
                          ),
                          child: const Text("Delete key & reset"),
                        ),
                      ]),
                ),
                if (widget.viewModel.deviceConnected)
                  _ServiceDiscoveryList(
                    deviceId: widget.viewModel.deviceId,
                    discoveredServices: discoveredServices,
                  ),
                // Display advertising payload data
                // if (advertisingPayloadData.isNotEmpty)
                //   Padding(
                //     padding: const EdgeInsets.all(16.0),
                //     child: Text('Advertising Payload: ${advertisingPayloadData.toString()}'),
                //   ),
              ],
            ),
          ),
        ],
      );
}

class _ServiceDiscoveryList extends StatefulWidget {
  const _ServiceDiscoveryList({
    required this.deviceId,
    required this.discoveredServices,
    Key? key,
  }) : super(key: key);

  final String deviceId;
  final List<DiscoveredService> discoveredServices;

  @override
  _ServiceDiscoveryListState createState() => _ServiceDiscoveryListState();
}

class _ServiceDiscoveryListState extends State<_ServiceDiscoveryList> {
  late final List<int> _expandedItems;

  @override
  void initState() {
    _expandedItems = [];
    super.initState();
  }

  String _charactisticsSummary(DiscoveredCharacteristic c) {
    final props = <String>[];
    if (c.isReadable) {
      props.add("read");
    }
    if (c.isWritableWithoutResponse) {
      props.add("write without response");
    }
    if (c.isWritableWithResponse) {
      props.add("write with response");
    }
    if (c.isNotifiable) {
      props.add("notify");
    }
    if (c.isIndicatable) {
      props.add("indicate");
    }

    return props.join("\n");
  }

  Widget _characteristicTile(
          DiscoveredCharacteristic characteristic, String deviceId) =>
      ListTile(
        onTap: () => showDialog<void>(
            context: context,
            builder: (context) => CharacteristicInteractionDialog(
                  characteristic: QualifiedCharacteristic(
                      characteristicId: characteristic.characteristicId,
                      serviceId: characteristic.serviceId,
                      deviceId: deviceId),
                )),
        title: Text(
          '${characteristic.characteristicId}\n(${_charactisticsSummary(characteristic)})',
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
      );

  List<ExpansionPanel> buildPanels() {
    final panels = <ExpansionPanel>[];

    widget.discoveredServices.asMap().forEach(
          (index, service) => panels.add(
            ExpansionPanel(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 16.0),
                    child: Text(
                      'Characteristics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    itemBuilder: (context, index) => _characteristicTile(
                      service.characteristics[index],
                      widget.deviceId,
                    ),
                    itemCount: service.characteristicIds.length,
                  ),
                ],
              ),
              headerBuilder: (context, isExpanded) => ListTile(
                title: Text(
                  '${service.serviceId}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              isExpanded: _expandedItems.contains(index),
            ),
          ),
        );

    return panels;
  }

  @override
  Widget build(BuildContext context) => widget.discoveredServices.isEmpty
      ? const SizedBox()
      : Padding(
          padding: const EdgeInsetsDirectional.only(
            top: 20.0,
            start: 20.0,
            end: 20.0,
          ),
          child: ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                setState(() {
                  if (isExpanded) {
                    _expandedItems.remove(index);
                  } else {
                    _expandedItems.add(index);
                  }
                });
              });
            },
            children: [
              ...buildPanels(),
            ],
          ),
        );
}
