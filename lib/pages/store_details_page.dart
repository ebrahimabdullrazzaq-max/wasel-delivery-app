import 'package:flutter/material.dart';
import 'package:wasel/models/store.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreDetailsPage extends StatelessWidget {
  final Store store;

  const StoreDetailsPage({Key? key, required this.store}) : super(key: key);

  void _openInGoogleMaps() async {
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${store.latitude},${store.longitude}';
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not open the map.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(store.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (store.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(store.image, height: 200, fit: BoxFit.cover),
              ),
            SizedBox(height: 20),
            Text(store.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(store.address, style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Text('Distance: ${store.distance.toStringAsFixed(2)} km'),
            Spacer(),
            ElevatedButton.icon(
              onPressed: _openInGoogleMaps,
              icon: Icon(Icons.map),
              label: Text("Open in Google Maps"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
