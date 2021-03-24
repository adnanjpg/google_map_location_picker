import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_map_location_picker/google_map_location_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickerModel {
  final LatLng initialCenter;
  final double initialZoom;
  final List<String> countries;
  final bool requiredGPS;
  final bool myLocationButtonEnabled;
  final bool layersButtonEnabled;
  final bool automaticallyAnimateToCurrentLocation;

  /// Show the widget at the bottom that shows
  /// your current selected place's name;
  ///
  /// Default to false;
  ///
  /// For turning it on you have to enable
  /// places API from [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/)
  /// which requires billing;
  final bool showLocationCard;

  final Color appBarColor;
  final BoxDecoration searchBarBoxDecoration;
  final Widget resultCardConfirmIcon;
  final AlignmentGeometry resultCardAlignment;
  final EdgeInsetsGeometry resultCardPadding;
  final Decoration resultCardDecoration;
  final LocationAccuracy desiredAccuracy;

  /// Get from  [Google Cloud](https://cloud.google.com/maps-platform/)
  ///
  /// - Maps SDK for Android
  /// - Maps SDK for iOS
  /// - Geolocation API
  /// - Geocoding API
  ///
  ///   are required
  ///
  ///
  /// - Places API
  ///
  ///  only for [showLocationCard]
  final String apiKey;
  final String mapStylePath;
  final String hintText;
  final String language;

  const PickerModel(
    this.apiKey, {
    Key key,
    this.initialCenter = const LatLng(45.521563, -122.677433),
    this.initialZoom = 16,
    this.requiredGPS = false,
    this.myLocationButtonEnabled = false,
    this.layersButtonEnabled = false,
    this.automaticallyAnimateToCurrentLocation = true,
    this.showLocationCard = false,
    this.mapStylePath,
    this.appBarColor = Colors.transparent,
    this.searchBarBoxDecoration,
    this.hintText,
    this.resultCardConfirmIcon,
    this.resultCardAlignment,
    this.resultCardDecoration,
    this.resultCardPadding,
    this.countries,
    this.language = 'en',
    this.desiredAccuracy = LocationAccuracy.best,
  });
}
