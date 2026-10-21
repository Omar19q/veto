import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Existing public avatars keep their provider. New onboarding portraits are
/// downloaded under the viewer's Storage RLS and cached separately per account.
ImageProvider<Object> captainPhotoV16(String source) =>
    source.startsWith('v16-private://')
    ? _PrivatePortrait(
        source.substring(14),
        Supabase.instance.client.auth.currentUser?.id ?? '',
      )
    : NetworkImage(source);

class _PrivatePortrait extends ImageProvider<_PrivatePortrait> {
  const _PrivatePortrait(this.path, this.viewer);
  final String path;
  final String viewer;
  @override
  Future<_PrivatePortrait> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _PrivatePortrait key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    if (Supabase.instance.client.auth.currentUser?.id != viewer)
      throw StateError('session_changed');
    final bytes = await Supabase.instance.client.storage
        .from('v16-captain-documents')
        .download(path);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is _PrivatePortrait && other.path == path && other.viewer == viewer;
  @override
  int get hashCode => Object.hash(path, viewer);
}
