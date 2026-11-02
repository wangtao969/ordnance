import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../location_flow.dart';
import 'app_toast.dart';

/// 应用内地图预览（零第三方包）：OSM 瓦片拼图 + 图钉。
/// 拖动平移、双击放大、右下角 ± 缩放；点地图跳系统地图。
/// 瓦片失败时灰块占位 + 顶部失败提示；离线时整图灰块加提示，
/// 不阻塞页面其他内容。地名用 Nominatim 反查，查不到显示经纬度。
class MapPreview extends StatefulWidget {
  final double lat;
  final double lon;
  final double height;
  final bool showLabel;
  const MapPreview({
    super.key,
    required this.lat,
    required this.lon,
    this.height = 180,
    this.showLabel = true,
  });

  @override
  State<MapPreview> createState() => _MapPreviewState();
}

double _tileX(double lon, int z) => (lon + 180) / 360 * (1 << z);

double _tileY(double lat, int z) {
  final r = lat * math.pi / 180;
  return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) /
      2 *
      (1 << z);
}

double _lonForX(double x, int z) => x / (1 << z) * 360 - 180;

double _latForY(double y, int z) {
  final v = math.pi * (1 - 2 * y / (1 << z));
  return math.atan((math.exp(v) - math.exp(-v)) / 2) * 180 / math.pi;
}

class _MapPreviewState extends State<MapPreview> {
  int _zoom = 15;
  late double _centerLat;
  late double _centerLon;
  bool _tileFailed = false;
  String? _placeName;

  @override
  void initState() {
    super.initState();
    _centerLat = widget.lat;
    _centerLon = widget.lon;
    _resolveName();
  }

  @override
  void didUpdateWidget(MapPreview old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lon != widget.lon) {
      _centerLat = widget.lat;
      _centerLon = widget.lon;
      _tileFailed = false;
      _placeName = null;
      _resolveName();
    }
  }

  Future<void> _resolveName() async {
    if (!widget.showLabel) return;
    final name = await reverseGeocode(widget.lat, widget.lon);
    if (mounted && name != null) setState(() => _placeName = name);
  }

  void _markTileFailed() {
    if (_tileFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileFailed) setState(() => _tileFailed = true);
    });
  }

  void _onPan(DragUpdateDetails d) {
    final n = (1 << _zoom).toDouble();
    final dx = d.delta.dx / 256 / n;
    final dy = d.delta.dy / 256 / n;
    var lon = _lonForX(_tileX(_centerLon, _zoom) - dx, _zoom);
    if (lon > 180) lon -= 360;
    if (lon < -180) lon += 360;
    var lat = _latForY(_tileY(_centerLat, _zoom) - dy, _zoom);
    if (lat > 85) lat = 85;
    if (lat < -85) lat = -85;
    setState(() {
      _centerLon = lon;
      _centerLat = lat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final coords =
        '${widget.lat.toStringAsFixed(5)}, ${widget.lon.toStringAsFixed(5)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _placeName ?? coords,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.height,
            color: dark ? const Color(0xFF1A1A1A) : const Color(0xFFE8E2D6),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final n = 1 << _zoom;
                final cx = _tileX(_centerLon, _zoom) * 256;
                final cy = _tileY(_centerLat, _zoom) * 256;
                final ox = cx - w / 2;
                final oy = cy - h / 2;
                final x0 = (ox / 256).floor();
                final x1 = ((ox + w) / 256).floor();
                final y0 = (oy / 256).floor().clamp(0, n - 1);
                final y1 = ((oy + h) / 256).floor().clamp(0, n - 1);
                final pinX = _tileX(widget.lon, _zoom) * 256 - ox;
                final pinY = _tileY(widget.lat, _zoom) * 256 - oy;
                final pinVisible = pinX >= 0 &&
                    pinX <= w &&
                    pinY >= 0 &&
                    pinY <= h;
                return GestureDetector(
                  onPanUpdate: _onPan,
                  onDoubleTap: () {
                    if (_zoom < 18) setState(() => _zoom++);
                  },
                  onTap: () async {
                    final ok =
                        await openMapAt(widget.lat, widget.lon);
                    if (!ok && context.mounted) {
                      showAppToast(context, tr('loc_map_open_failed'));
                    }
                  },
                  child: Stack(
                    children: [
                      for (var x = x0; x <= x1; x++)
                        for (var y = y0; y <= y1; y++)
                          Positioned(
                            left: x * 256 - ox,
                            top: y * 256 - oy,
                            width: 256,
                            height: 256,
                            child: Image.network(
                              'https://tile.openstreetmap.org/$_zoom/${((x % n) + n) % n}/$y.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                _markTileFailed();
                                return Container(
                                  color: dark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFD8D2C4),
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 20,
                                      color: Colors.grey),
                                );
                              },
                            ),
                          ),
                      if (pinVisible)
                        Positioned(
                          left: pinX - 16,
                          top: pinY - 32,
                          child: const Icon(Icons.location_on,
                              size: 32, color: Color(0xFFE86A1C)),
                        ),
                      Positioned(
                        left: 6,
                        bottom: 4,
                        child: Text(
                          '© OpenStreetMap',
                          style: TextStyle(
                              fontSize: 10,
                              color: grey,
                              backgroundColor: (dark
                                      ? Colors.black
                                      : Colors.white)
                                  .withValues(alpha: 0.55)),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Column(
                          children: [
                            _ZoomBtn(
                              icon: Icons.add,
                              onTap: () {
                                if (_zoom < 18) {
                                  setState(() => _zoom++);
                                }
                              },
                            ),
                            const SizedBox(height: 4),
                            _ZoomBtn(
                              icon: Icons.remove,
                              onTap: () {
                                if (_zoom > 13) {
                                  setState(() => _zoom--);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      if (_tileFailed)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            child: Text(
                              tr('loc_map_failed'),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('loc_map_hint'),
          style: TextStyle(fontSize: 12, color: grey),
        ),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
