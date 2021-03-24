import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_map_location_picker/generated/l10n.dart';
import 'package:google_map_location_picker/src/model/PickerModel.dart';
import 'package:google_map_location_picker/src/providers/location_provider.dart';
import 'package:google_map_location_picker/src/utils/loading_builder.dart';
import 'package:google_map_location_picker/src/utils/log.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../google_map_location_picker.dart';
import 'model/location_result.dart';
import 'utils/location_utils.dart';

class MapPicker extends StatefulWidget {
  const MapPicker(this.pickerModel);
  final PickerModel pickerModel;

  @override
  MapPickerState createState() => MapPickerState();
}

class MapPickerState extends State<MapPicker> {
  Completer<GoogleMapController> mapController = Completer();

  MapType _currentMapType = MapType.normal;

  String _mapStyle;

  LatLng _lastMapPosition;

  Position _currentPosition;

  String _address;

  String _placeId;

  void _onToggleMapTypePressed() {
    final MapType nextType =
        MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() => _currentMapType = nextType);
  }

  // this also checks for location permission.
  Future<void> _initCurrentLocation() async {
    Position currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: _model.desiredAccuracy);
      d("position = $currentPosition");

      setState(() => _currentPosition = currentPosition);
    } catch (e) {
      currentPosition = null;
      d("_initCurrentLocation#e = $e");
    }

    if (!mounted) return;

    setState(() => _currentPosition = currentPosition);

    if (currentPosition != null)
      moveToCurrentLocation(
          LatLng(currentPosition.latitude, currentPosition.longitude));
  }

  Future moveToCurrentLocation(LatLng currentLocation) async {
    d('MapPickerState.moveToCurrentLocation "currentLocation = [$currentLocation]"');
    final controller = await mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: currentLocation, zoom: 16),
    ));
  }

  PickerModel _model;
  @override
  void initState() {
    _model = widget.pickerModel;
    super.initState();
    if (_model.automaticallyAnimateToCurrentLocation && !_model.requiredGPS)
      _initCurrentLocation();

    if (_model.mapStylePath != null) {
      rootBundle.loadString(_model.mapStylePath).then((string) {
        _mapStyle = string;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_model.requiredGPS) {
      _checkGeolocationPermission();
      if (_currentPosition == null) _initCurrentLocation();
    }

    if (_currentPosition != null && dialogOpen != null)
      Navigator.of(context, rootNavigator: true).pop();

    return Scaffold(
      body: Builder(
        builder: (context) {
          if (_currentPosition == null &&
              _model.automaticallyAnimateToCurrentLocation &&
              _model.requiredGPS) {
            return const Center(child: CircularProgressIndicator());
          }

          return buildMap();
        },
      ),
    );
  }

  Widget buildMap() {
    return Center(
      child: Stack(
        children: <Widget>[
          GoogleMap(
            myLocationButtonEnabled: false,
            initialCameraPosition: CameraPosition(
              target: _model.initialCenter,
              zoom: _model.initialZoom,
            ),
            onMapCreated: (GoogleMapController controller) {
              mapController.complete(controller);
              //Implementation of mapStyle
              if (_model.mapStylePath != null) {
                controller.setMapStyle(_mapStyle);
              }

              _lastMapPosition = _model.initialCenter;
              LocationProvider.of(context, listen: false)
                  .setLastIdleLocation(_lastMapPosition);
            },
            onCameraMove: (CameraPosition position) {
              _lastMapPosition = position.target;
            },
            onCameraIdle: () async {
              print("onCameraIdle#_lastMapPosition = $_lastMapPosition");
              LocationProvider.of(context, listen: false)
                  .setLastIdleLocation(_lastMapPosition);
            },
            onCameraMoveStarted: () {
              print("onCameraMoveStarted#_lastMapPosition = $_lastMapPosition");
            },
//            onTap: (latLng) {
//              clearOverlay();
//            },
            mapType: _currentMapType,
            myLocationEnabled: true,
          ),
          _MapFabs(
            myLocationButtonEnabled: _model.myLocationButtonEnabled,
            layersButtonEnabled: _model.layersButtonEnabled,
            onToggleMapTypePressed: _onToggleMapTypePressed,
            onMyLocationPressed: _initCurrentLocation,
          ),
          pin(),
          locationCard(),
        ],
      ),
    );
  }

  Widget locationCard() {
    return Align(
      alignment: _model.resultCardAlignment ?? Alignment.bottomCenter,
      child: Padding(
        padding: _model.resultCardPadding ?? EdgeInsets.all(16.0),
        child:
            Consumer<LocationProvider>(builder: (context, locationProvider, _) {
          return _model.showLocationCard
              ? Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          flex: 20,
                          child: FutureLoadingBuilder<Map<String, String>>(
                            future:
                                getAddress(locationProvider.lastIdleLocation),
                            mutable: true,
                            loadingIndicator: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                CircularProgressIndicator(),
                              ],
                            ),
                            builder: (context, data) {
                              _address = data["address"];
                              _placeId = data["placeId"];
                              return Text(
                                _address ??
                                    S.of(context)?.unnamedPlace ??
                                    'Unnamed place',
                                style: TextStyle(fontSize: 18),
                              );
                            },
                          ),
                        ),
                        Spacer(),
                        floatingBtn(context, locationProvider),
                      ],
                    ),
                  ),
                )
              : floatingBtn(context, locationProvider);
        }),
      ),
    );
  }

  FloatingActionButton floatingBtn(
      BuildContext context, LocationProvider locationProvider) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).pop({
          'location': LocationResult(
            latLng: locationProvider.lastIdleLocation,
            address: _address,
            placeId: _placeId,
          )
        });
      },
      child: _model.resultCardConfirmIcon ?? Icon(Icons.arrow_forward),
    );
  }

  Future<Map<String, String>> getAddress(LatLng location) async {
    try {
      final endpoint =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location?.latitude},${location?.longitude}'
          '&key=${_model.apiKey}&language=${_model.language}';

      final response = jsonDecode((await http.get(Uri.parse(endpoint),
              headers: await LocationUtils.getAppHeaders()))
          .body);

      return {
        "placeId": response['results'][0]['place_id'],
        "address": response['results'][0]['formatted_address']
      };
    } catch (e) {
      print(e);
    }

    return {"placeId": null, "address": null};
  }

  Widget pin() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.place, size: 56),
            Container(
              decoration: ShapeDecoration(
                shadows: [
                  BoxShadow(
                    blurRadius: 4,
                    color: Colors.black38,
                  ),
                ],
                shape: CircleBorder(
                  side: BorderSide(
                    width: 4,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
            SizedBox(height: 56),
          ],
        ),
      ),
    );
  }

  var dialogOpen;

  Future _checkGeolocationPermission() async {
    final geolocationStatus = await Geolocator.checkPermission();
    d("geolocationStatus = $geolocationStatus");

    if (geolocationStatus == LocationPermission.denied && dialogOpen == null) {
      dialogOpen = _showDeniedDialog();
    } else if (geolocationStatus == LocationPermission.deniedForever &&
        dialogOpen == null) {
      dialogOpen = _showDeniedForeverDialog();
    } else if (geolocationStatus == LocationPermission.whileInUse ||
        geolocationStatus == LocationPermission.always) {
      d('GeolocationStatus.granted');

      if (dialogOpen != null) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = null;
      }
    }
  }

  Future _showDeniedDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context, rootNavigator: true).pop();
            return true;
          },
          child: AlertDialog(
            title: Text(S.of(context)?.access_to_location_denied ??
                'Access to location denied'),
            content: Text(
                S.of(context)?.allow_access_to_the_location_services ??
                    'Allow access to the location services.'),
            actions: <Widget>[
              TextButton(
                child: Text(S.of(context)?.ok ?? 'Ok'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _initCurrentLocation();
                  dialogOpen = null;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future _showDeniedForeverDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context, rootNavigator: true).pop();
            return true;
          },
          child: AlertDialog(
            title: Text(S.of(context)?.access_to_location_permanently_denied ??
                'Access to location permanently denied'),
            content: Text(S
                    .of(context)
                    ?.allow_access_to_the_location_services_from_settings ??
                'Allow access to the location services for this App using the device settings.'),
            actions: <Widget>[
              TextButton(
                child: Text(S.of(context)?.ok ?? 'Ok'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  Geolocator.openAppSettings();
                  dialogOpen = null;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapFabs extends StatelessWidget {
  const _MapFabs({
    Key key,
    @required this.myLocationButtonEnabled,
    @required this.layersButtonEnabled,
    @required this.onToggleMapTypePressed,
    @required this.onMyLocationPressed,
  })  : assert(onToggleMapTypePressed != null),
        super(key: key);

  final bool myLocationButtonEnabled;
  final bool layersButtonEnabled;

  final VoidCallback onToggleMapTypePressed;
  final VoidCallback onMyLocationPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.only(top: kToolbarHeight + 24, right: 8),
      child: Column(
        children: <Widget>[
          if (layersButtonEnabled)
            FloatingActionButton(
              onPressed: onToggleMapTypePressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              mini: true,
              child: const Icon(Icons.layers),
              heroTag: "layers",
            ),
          if (myLocationButtonEnabled)
            FloatingActionButton(
              onPressed: onMyLocationPressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              mini: true,
              child: const Icon(Icons.my_location),
              heroTag: "myLocation",
            ),
        ],
      ),
    );
  }
}
