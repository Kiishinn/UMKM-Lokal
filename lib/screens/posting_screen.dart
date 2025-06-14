import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class PostingScreen extends StatefulWidget {
  @override
  _PostingScreenState createState() => _PostingScreenState();
}

class _PostingScreenState extends State<PostingScreen> {
  dynamic _pickedImage;
  final picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  XFile? _imageFile;

  double _imageHeight = 150;
  double _imageWidth = double.infinity;

  String name = '';
  String jenisUsaha = '';  
  String tahunBerdiri = '';
  String deskripsi = '';
  String selectedTimeUnit = 'Tahun';

  LatLng? selectedLocation;
  LatLng defaultLocation = LatLng(-2.990934, 104.756554);
  String? selectedAddress;
  bool _isManualLocation = false;  // Flag for manual location input

  final List<String> timeUnits = ['Hari', 'Minggu', 'Bulan', 'Tahun'];
  final List<String> jenisUsahaOptions = [
    'Makanan & Minuman',
    'Pakaian',
    'Elektronik',
    'Furnitur',
    'Jasa',
    'Lainnya',
  ];

  bool _isLoading = false;  

  TextEditingController _manualLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndGetLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        selectedLocation = LatLng(position.latitude, position.longitude);
        selectedAddress = null;
      });
      await _updateAddress(selectedLocation!);
    } catch (e) {
      print("Gagal mendapatkan lokasi: $e");
    }
  }

  Future<void> _checkLocationPermissionAndGetLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Izin lokasi ditolak');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print('Izin lokasi ditolak permanen');
      return;
    }
    if (!_isManualLocation) {  // Only get current location if not using manual input
      _getCurrentLocation();
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        setState(() {
          selectedAddress = address;
        });
      } else {
        setState(() {
          selectedAddress = 'Alamat tidak ditemukan';
        });
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
      setState(() {
        selectedAddress = 'Gagal mendapatkan alamat';
      });
    }
  }

  Future<void> _searchLocationByAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          selectedLocation = LatLng(locations[0].latitude, locations[0].longitude);
        });
        await _updateAddress(selectedLocation!);
      } else {
        print("Alamat tidak ditemukan");
      }
    } catch (e) {
      print("Error geocoding address: $e");
    }
  }

  Future<String?> compressAndEncodeImage(XFile? imageFile,
      {int maxWidth = 400, int quality = 70}) async {
    if (imageFile == null) return null;
    final bytes = await File(imageFile.path).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    img.Image resized = img.copyResize(image, width: maxWidth);

    List<int> jpg = img.encodeJpg(resized, quality: quality);

    if (jpg.length > 900 * 1024) {
      return null;
    }

    return base64Encode(jpg);
  }

  Future<void> saveUMKMData() async {
    String? imageBase64 = await compressAndEncodeImage(_imageFile);

    if (_imageFile != null && imageBase64 == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ukuran gambar terlalu besar!')));
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('umkms').add({
      'name': name,
      'jenis_usaha': jenisUsaha,  
      'tahun_berdiri': tahunBerdiri,
      'deskripsi': deskripsi,
      'latitude': selectedLocation?.latitude,
      'longitude': selectedLocation?.longitude,
      'alamat': selectedAddress ?? _manualLocationController.text,
      'image_base64': imageBase64,
      'uid': userId,
      'created_at': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Data berhasil disimpan!')));
    Navigator.pop(context);
  }

  void _resetForm() {
    setState(() {
      _formKey.currentState?.reset();
      _pickedImage = null;
      _imageFile = null;
      name = '';
      jenisUsaha = '';  
      tahunBerdiri = '';
      deskripsi = '';
      selectedTimeUnit = 'Tahun';
      selectedAddress = null;
      _manualLocationController.clear();
      _isManualLocation = false;  // Reset manual location flag
    });
  }

  Widget _buildImageWidget() {
    if (_pickedImage == null) {
      return Center(
        child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey[700]),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _pickedImage,
          fit: BoxFit.contain,
          width: _imageWidth,
          height: _imageHeight,
        ),
      );
    }
  }

  Widget _buildTextField(
    String label,
    Function(String) onSaved, {
    String? initialValue,
    String? Function(String?)? customValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14),
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        style: TextStyle(fontSize: 14),
        validator:
            customValidator ?? (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Wajib diisi';
          }
          return null;
        },
        onSaved: (val) => onSaved(val!.trim()),
      ),
    );
  }

  Widget _buildJenisUsahaDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Jenis Usaha',
          labelStyle: TextStyle(fontSize: 14),
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        value: jenisUsaha.isEmpty ? null : jenisUsaha,
        items: jenisUsahaOptions
            .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            })
            .toList(),
        onChanged: (newValue) {
          setState(() {
            jenisUsaha = newValue!;
          });
        },
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'Wajib memilih jenis usaha';
          }
          return null;
        },
        onSaved: (val) {
          jenisUsaha = val!;
        },
      ),
    );
  }

  Widget _buildFlutterMap() {
    final LatLng mapCenter = selectedLocation ?? defaultLocation;
    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: mapCenter,
          initialZoom: 15,
          onTap: (tapPos, latlng) async {
            if (!_isManualLocation) {  // Disable map and current location if manual location is selected
              setState(() {
                selectedLocation = latlng;
                selectedAddress = null;
              });
              await _updateAddress(latlng);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          if (selectedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selectedLocation!,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.location_on, size: 40, color: Colors.red),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black45 : Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Text(
                  'Posting UMKM',
                  style: TextStyle(
                    color: Color(0xFF6FCF97),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 150), // Placeholder for back button
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: _imageHeight,
                  width: _imageWidth,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildImageWidget(),
                ),
              ),
              SizedBox(height: 16),
              _buildTextField('Nama UMKM', (val) => name = val),
              _buildJenisUsahaDropdown(),
              _buildTextField('Deskripsi Usaha', (val) => deskripsi = val),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Tahun Berdiri',
                    labelStyle: TextStyle(fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  style: TextStyle(fontSize: 14),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Wajib diisi';
                    }
                    return null;
                  },
                  onSaved: (val) => tahunBerdiri = val!,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Pilih Lokasi Usaha: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isManualLocation = false;  // Switch to map
                        _getCurrentLocation();
                      });
                    },
                    icon: Icon(Icons.my_location, color: Colors.green),
                    label: Text("Ambil Lokasi Saya"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[350],
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isManualLocation = true;  // Switch to manual typing
                        selectedLocation = null;  // Clear map location
                        selectedAddress = null;   // Clear address
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[350],
                    ),
                    child: Text("Ketik Lokasi"),
                  ),
                ],
              ),
              SizedBox(height: 10),
              _isManualLocation
                  ? TextField(
                      controller: _manualLocationController,
                      decoration: InputDecoration(
                        labelText: 'Masukkan Alamat Manual',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      onChanged: (val) async {
                        if (val.trim().isNotEmpty) {
                          await _searchLocationByAddress(val);  // Update map when typing in text field
                        }
                      },
                    )
                  : _buildFlutterMap(),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selectedAddress ?? 'Alamat belum tersedia',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle:
                          selectedLocation != null
                              ? Text(
                                  'Lat: ${selectedLocation!.latitude.toStringAsFixed(5)}, Lng: ${selectedLocation!.longitude.toStringAsFixed(5)}',
                                  style: TextStyle(fontSize: 11),
                                )
                              : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_imageFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Harap pilih gambar terlebih dahulu'),
                        ),
                      );
                      return;
                    }
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      try {
                        await saveUMKMData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Berhasil posting!')),
                          );
                          _resetForm();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal posting: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6FCF97),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Posting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
