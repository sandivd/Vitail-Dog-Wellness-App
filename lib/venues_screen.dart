import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VenuesScreen extends StatefulWidget {
  const VenuesScreen({super.key});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  bool _isListView = true;

  // Mock data matching your image
  final List<Map<String, dynamic>> _venues = [
    {
      'name': 'The Local Scone Cafe',
      'type': 'Cafe',
      'distance': '350m',
      'rating': 4.9,
      'amenities': ['Water Bowls', 'Dog Treat Menu'],
      'location': const LatLng(-37.8140, 144.9631),
      'icon': Icons.coffee,
      'color': Colors.brown,
    },
    {
      'name': 'Sirius Cove Beach',
      'type': 'Beach',
      'distance': '1.2km',
      'rating': 4.8,
      'amenities': ['Off-Leash', 'Dog Wash Station'],
      'location': const LatLng(-37.8150, 144.9650),
      'icon': Icons.beach_access,
      'color': Colors.blue,
    },
    {
      'name': 'Yarra Bend Dog Park',
      'type': 'Park',
      'distance': '2.5km',
      'rating': 4.7,
      'amenities': ['Fully Fenced', 'Shaded Areas'],
      'location': const LatLng(-37.8160, 144.9670),
      'icon': Icons.park,
      'color': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Venues'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Toggle Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isListView = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListView ? Colors.green : Colors.grey[300],
                      foregroundColor: _isListView ? Colors.white : Colors.black,
                    ),
                    child: const Text('List View'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isListView = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isListView ? Colors.green : Colors.grey[300],
                      foregroundColor: !_isListView ? Colors.white : Colors.black,
                    ),
                    child: const Text('Map View'),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isListView ? _buildListView() : _buildMapView(),
          ),
        ],
      ),
    );
  }

  // List View UI
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _venues.length,
      itemBuilder: (context, index) {
        final venue = _venues[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: venue['color'].withOpacity(0.2),
                  child: Icon(venue['icon'], color: venue['color']),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(venue['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(venue['type'], style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(' ${venue['rating']}', style: const TextStyle(color: Colors.grey)),
                          const Spacer(),
                          Text(venue['distance'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: (venue['amenities'] as List<String>).map((a) {
                          return Chip(
                            label: Text(a, style: const TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Map View UI
  Widget _buildMapView() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-37.8150, 144.9650), // Centered between the venues
        zoom: 14,
      ),
      markers: _venues.map((venue) {
        return Marker(
          markerId: MarkerId(venue['name']),
          position: venue['location'],
          infoWindow: InfoWindow(title: venue['name']),
        );
      }).toSet(),
    );
  }
}