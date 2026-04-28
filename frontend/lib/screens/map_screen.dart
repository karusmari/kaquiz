import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  GoogleMapController? _mapController;
  Timer? _locationTimer;
  LatLng _currentPosition = const LatLng(59.437, 24.7535); // Vaikimisi Tallinn

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Küsime asukoha luba
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    // Paneme käima taimeri: Iga 5 sekundi järel
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });

        // SAADAME BACKENDI (Auditi nõue!)
        await _apiService.updateLocation(position.latitude, position.longitude);
        print("Location updated: ${position.latitude}, ${position.longitude}");
      } catch (e) {
        print("Error updating location: $e");
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel(); // Peatame taimeri, kui kasutaja lahkub
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KaQuiz Map"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              // Siiia lisame hiljem sõprade otsimise dialoogi
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14,
        ),
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true, // Näitab sinist täppi kaardil
        markers: {
          // Siia hakkame hiljem lisama sõprade markereid
          Marker(
            markerId: const MarkerId('me'),
            position: _currentPosition,
            infoWindow: const InfoWindow(title: "Me"),
          ),
        },
      ),
    );
  }

  void _showSearchDialog() {
    final TextEditingController _emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Search friend by email"),
        content: TextField(
          controller: _emailController,
          decoration: const InputDecoration(hintText: "Friend's email"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = await _apiService.searchUserByEmail(_emailController.text);
              if (user != null) {
                // Sõber leitud, siia saame panna kutse saatmise loogika
                print("Found user ID: ${user['id']}");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Friend found!")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User not found")),
                );
              }
            },
            child: const Text("Otsi"),
          ),
        ],
      ),
    );
  }
}