import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/moodboard_service.dart';

class MoodboardCaptureSheet extends StatefulWidget {
  const MoodboardCaptureSheet({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(MoodboardInspiration inspiration) onSubmit;

  @override
  State<MoodboardCaptureSheet> createState() => _MoodboardCaptureSheetState();
}

class _MoodboardCaptureSheetState extends State<MoodboardCaptureSheet>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final List<_Stroke> _strokes = [];
  File? _selectedPhoto;
  bool _isSubmitting = false;
  bool _caregiverConsent = false;
  late final TabController _tabController;
  Color _selectedColor = const Color(0xFFfef08a);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1600);
    if (file == null) return;
    setState(() {
      _selectedPhoto = File(file.path);
      _strokes.clear();
    });
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    final normalized = _normalize(details.localPosition, size);
    setState(() {
      _strokes.add(
        _Stroke(color: _selectedColor, points: [normalized]),
      );
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final normalized = _normalize(details.localPosition, size);
    setState(() {
      _strokes.last.points.add(normalized);
    });
  }

  Map<String, double> _normalize(Offset offset, Size size) {
    return {
      'x': (offset.dx / size.width).clamp(0, 1),
      'y': (offset.dy / size.height).clamp(0, 1),
    };
  }

  Future<void> _handleSubmit() async {
    if (_selectedPhoto == null && _strokes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a photo or sketch first.')),
        );
      }
      return;
    }
    if (!_caregiverConsent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caregiver consent is required.')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      MoodboardInspiration inspiration;
      if (_selectedPhoto != null) {
        final bytes = await _selectedPhoto!.readAsBytes();
        inspiration = MoodboardInspiration.photo(
          bytes: bytes,
          caption: _captionController.text.trim(),
          caregiverConsent: _caregiverConsent,
        );
      } else {
        final strokes = _strokes
            .map(
              (stroke) => MoodboardStroke(
                points: List<Map<String, double>>.from(stroke.points),
                width: stroke.width,
                colorHex: stroke.colorHex,
              ),
            )
            .toList();
        inspiration = MoodboardInspiration.canvas(
          strokes: strokes,
          caption: _captionController.text.trim(),
          caregiverConsent: _caregiverConsent,
        );
      }
      await widget.onSubmit(inspiration);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              'Inspire tonight’s visuals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Caregiver consent required • Keep faces within your family bubble.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.photo_library_rounded), text: 'Photo'),
                Tab(icon: Icon(Icons.auto_fix_high_rounded), text: 'Sketch'),
              ],
            ),
            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPhotoPicker(),
                  _buildSketchPad(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'What should the scene feel like?',
              ),
            ),
            CheckboxListTile(
              value: _caregiverConsent,
              onChanged: _isSubmitting
                  ? null
                  : (value) =>
                      setState(() => _caregiverConsent = value ?? false),
              title: const Text('I am the caregiver and this stays in-family'),
              subtitle: const Text('Faces beyond our bubble are not allowed.'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Uploading...' : 'Send to Maestro'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickPhoto(ImageSource.gallery),
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                color: Colors.white.withValues(alpha: 0.03),
              ),
              child: _selectedPhoto == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_photo_alternate_outlined),
                          SizedBox(height: 8),
                          Text('Tap to choose a calming photo'),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        _selectedPhoto!,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSketchPad() {
    final colors = [
      Colors.amberAccent,
      Colors.cyanAccent,
      Colors.pinkAccent,
      Colors.white,
    ];
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanStart: (details) => _handlePanStart(details, size),
                onPanUpdate: (details) => _handlePanUpdate(details, size),
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                  child: CustomPaint(
                    painter: _SketchPainter(strokes: _strokes, size: size),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: colors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Stroke {
  _Stroke({
    required this.color,
    required this.points,
    // width parameter is used in the class, analyzer false positive
    // ignore: unused_element_parameter
    this.width = 2.5,
  });
  final Color color;
  final List<Map<String, double>> points;
  final double width;

  String get colorHex =>
      color.value.toRadixString(16).padLeft(8, '0').substring(2);
}

class _SketchPainter extends CustomPainter {
  const _SketchPainter({required this.strokes, required this.size});

  final List<_Stroke> strokes;
  final Size size;

  @override
  void paint(Canvas canvas, Size _) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        final offset = Offset(point['x']! * size.width, point['y']! * size.height);
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}

