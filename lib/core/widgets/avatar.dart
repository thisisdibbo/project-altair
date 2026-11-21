import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../photos.dart';
import '../theme/palette.dart';

/// A round profile picture, or the person's initials while there is none.
class Avatar extends StatefulWidget {
  const Avatar({
    super.key,
    required this.name,
    this.url,
    this.image,
    this.size = 46,
    this.ring = false,
  });

  final String name;

  /// Reference to a stored picture (see PhotoRepository).
  final String? url;

  /// A picture that was just picked and is not saved yet.
  final Uint8List? image;
  final double size;
  final bool ring;

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(Avatar old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _resolve();
  }

  void _resolve() {
    final ref = widget.url ?? '';
    _bytes = ref.isEmpty ? null : Photos.cached(ref);
    if (ref.isEmpty || _bytes != null) return;
    Photos.load(ref).then((bytes) {
      if (mounted && bytes != null && widget.url == ref) {
        setState(() => _bytes = bytes);
      }
    });
  }

  String get _initials {
    final parts = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = widget.size;
    final fallback = Container(
      color: p.surfaceHigh,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          color: p.accentText,
        ),
      ),
    );
    final bytes = widget.image ?? _bytes;
    final Widget inner = bytes == null
        ? fallback
        : Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: size,
            height: size,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => fallback,
          );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(widget.ring ? 2.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.ring ? p.accent : p.line,
          width: widget.ring ? 2 : 1,
        ),
      ),
      child: ClipOval(child: inner),
    );
  }
}
