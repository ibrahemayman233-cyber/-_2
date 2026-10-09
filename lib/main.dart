import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const QiblaApp());

class QiblaApp extends StatelessWidget {
  const QiblaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اتجاه القبلة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B6B4D),
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const QiblaPage(),
    );
  }
}

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  static const double kaabaLat = 21.4225;
  static const double kaabaLng = 39.8262;

  double? _qiblaBearing;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  double _calculateQibla(double lat, double lng) {
    final phi1 = _toRad(lat);
    final phi2 = _toRad(kaabaLat);
    final dLambda = _toRad(kaabaLng - lng);

    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);

    final bearing = math.atan2(y, x);
    return (_toDeg(bearing) + 360) % 360;
  }

  double _toRad(double deg) => deg * math.pi / 180;
  double _toDeg(double rad) => rad * 180 / math.pi;

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'خدمة الموقع (GPS) مغلقة، فعّلها وحاول مرة أخرى.';
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw 'تم رفض إذن الموقع.';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'إذن الموقع مرفوض نهائيًا، فعّله من إعدادات الجهاز.';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _qiblaBearing = _calculateQibla(pos.latitude, pos.longitude);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اتجاه القبلة'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث الموقع',
            onPressed: _init,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const CircularProgressIndicator();

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _init, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('تعذّر قراءة البوصلة.');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final heading = snapshot.data?.heading;
        if (heading == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'جهازك لا يحتوي على حساس بوصلة.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final qibla = _qiblaBearing!;
        var diff = (qibla - heading) % 360;
        if (diff > 180) diff -= 360;
        final aligned = diff.abs() < 3;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_drop_down,
              size: 48,
              color: aligned ? Colors.green : Colors.grey,
            ),
            _CompassDial(
              rotation: -_toRad(heading),
              qiblaAngle: _toRad(qibla),
              aligned: aligned,
            ),
            const SizedBox(height: 28),
            Text(
              aligned
                  ? 'أنت باتجاه القبلة ✓'
                  : 'أدِر الهاتف حتى تتطابق الكعبة مع المؤشر',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: aligned ? Colors.green : null,
              ),
            ),
            const SizedBox(height: 8),
            Text('زاوية القبلة: ${qibla.toStringAsFixed(1)}°'),
            Text('اتجاه الهاتف: ${heading.toStringAsFixed(1)}°'),
          ],
        );
      },
    );
  }
}

class _CompassDial extends StatelessWidget {
  const _CompassDial({
    required this.rotation,
    required this.qiblaAngle,
    required this.aligned,
  });

  final double rotation;
  final double qiblaAngle;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    const size = 280.0;
    final color =
        aligned ? Colors.green : Theme.of(context).colorScheme.primary;

    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4),
                color: color.withOpacity(0.06),
              ),
            ),
            const Align(
                alignment: Alignment.topCenter, child: _Dir('N', Colors.red)),
            const Align(
                alignment: Alignment.bottomCenter,
                child: _Dir('S', Colors.grey)),
            const Align(
                alignment: Alignment.centerRight,
                child: _Dir('E', Colors.grey)),
            const Align(
                alignment: Alignment.centerLeft,
                child: _Dir('W', Colors.grey)),
            Transform.rotate(
              angle: qiblaAngle,
              child: SizedBox(
                width: size,
                height: size,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🕋', style: TextStyle(fontSize: 40)),
                        Container(width: 4, height: 80, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dir extends StatelessWidget {
  const _Dir(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          label,
          style:
              TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      );
}