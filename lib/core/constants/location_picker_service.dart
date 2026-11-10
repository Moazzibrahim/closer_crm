// location_picker_screen.dart
// خريطة مجانية 100%: flutter_map + OpenStreetMap data (من غير API key ولا حساب).
// بيرجّع LatLng (من latlong2) لما المستخدم يأكد، أو null لو رجع.
// الاستخدام:
//   final r = await Navigator.push<LatLng>(context,
//       MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: old)));
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// نقطة البداية لو مفيش موقع محفوظ (دبي) — الخريطة نفسها مفتوحة على العالم كله
const _dubai = LatLng(25.2048, 55.2708);

double _r6(double v) => double.parse(v.toStringAsFixed(6));

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial; // لو null بنبدأ من دبي
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _search = TextEditingController();

  late LatLng _center;
  late final bool _hasInitial;
  bool _satellite = false;
  bool _moving = false, _searching = false;

  @override
void initState() {
  super.initState();

  final init = widget.initial;
  _hasInitial = init != null;
  _center = _hasInitial ? init! : _dubai;

  if (!_hasInitial) {
    _getCurrentLocation();
  }
}

Future<void> _getCurrentLocation() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _snack('Please enable location services');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _snack('Location permission denied');
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _snack('Location permission is permanently denied');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!mounted) return;

    final currentLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _center = currentLocation;
    });

    _map.move(currentLocation, 16);
  } catch (e) {
    debugPrint('❌ Location error: $e');
  }
}
  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
      ),
    );
  }

  // بحث بالاسم (مثلاً "Downtown Dubai") — Nominatim مجاني وبدون key
  Future<void> _doSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      // Nominatim (بحث OSM المجاني): من غير key، بس لازم User-Agent
      // وحد أقصى طلب في الثانية — وإحنا بنبحث عند الضغط على Search بس فمفيش مشكلة
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'jsonv2',
          'limit': 5,
          'accept-language': 'en', // نتايج البحث بالإنجليزي
        },
        options: Options(
          headers: {'User-Agent': 'flutter_application_1/1.0'},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final hits = (res.data as List)
          .map(
            (e) => LatLng(
              double.tryParse('${e['lat']}') ?? 0,
              double.tryParse('${e['lon']}') ?? 0,
            ),
          )
          .where(
            (p) => p.latitude != 0 || p.longitude != 0,
          ) // نتجاهل أي نتيجة بايظة
          .toList();
      if (hits.isEmpty) {
        _snack('No results found');
      } else {
        _map.move(hits.first, 16);
      }
    } catch (_) {
      _snack('Could not find this place');
    }
    if (mounted) setState(() => _searching = false);
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, bool isDark) => Material(
    color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
    shape: const CircleBorder(),
    elevation: 3,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(
          icon,
          size: 22,
          color: isDark ? AppColors.goldLight : AppColors.navy,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1E1E1E) : AppColors.white;

    return Scaffold(
      // مفيش AppBar: الـ pin في نص الشاشة بالظبط = نص الخريطة
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _hasInitial ? 16 : 11,
              minZoom: 2,
              maxZoom: 19,
              // بنقفل الدوران عشان الاتجاه يفضل ثابت
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapEvent: (e) {
                if (e is MapEventMoveStart) setState(() => _moving = true);
                if (e is MapEventMoveEnd) setState(() => _moving = false);
                // الإحداثيات بتتحدث لايف مع الحركة
                if (e.camera.center != _center) {
                  setState(() => _center = e.camera.center);
                }
              },
            ),
            children: [
              if (!_satellite)
                TileLayer(
                  // Esri World Street Map: من غير key، والأسماء عالمياً بالإنجليزي
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  // ⚠️ لازم يطابق الـ applicationId بتاع تطبيقك
                  userAgentPackageName: 'com.example.flutter_application_1',
                  maxNativeZoom: 19,
                )
              else
                TileLayer(
                  // صور أقمار صناعية من Esri (مجانية للتجربة/الاستخدام الخفيف)
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.flutter_application_1',
                  maxNativeZoom: 19,
                ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    _satellite
                        ? 'Esri, Maxar, Earthstar'
                        : 'Esri, HERE, Garmin, © OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),

          // ---- Pin ثابت في النص، والخريطة هي اللي بتتحرك تحته ----
          IgnorePointer(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                // طرف الـ pin بيلمس نص الشاشة، وبيترفع شوية وقت الحركة
                transform: Matrix4.translationValues(0, _moving ? -34 : -24, 0),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: AppColors.gold,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                ),
              ),
            ),
          ),

          // ---- Top bar: رجوع + بحث + نوع الخريطة ----
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _roundBtn(
                    Icons.arrow_back_rounded,
                    () => Navigator.pop(context),
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: card,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(24),
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _doSearch(),
                        decoration: InputDecoration(
                          hintText: 'Search any place',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.search_rounded),
                                  onPressed: _doSearch,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // خريطة عادية ⇄ قمر صناعي
                  _roundBtn(
                    _satellite
                        ? Icons.map_rounded
                        : Icons.satellite_alt_rounded,
                    () => setState(() => _satellite = !_satellite),
                    isDark,
                  ),
                ],
              ),
            ),
          ),

          // ---- Bottom card: الإحداثيات + تأكيد ----
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Material(
                color: card,
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.place_rounded,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_r6(_center.latitude)},  ${_r6(_center.longitude)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(
                            context,
                            LatLng(
                              _r6(_center.latitude),
                              _r6(_center.longitude),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Confirm location',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
