import 'dart:convert';
import 'package:flutter/material.dart';

ImageProvider getAvatarProvider(dynamic avatar) {
  if (avatar == null || (avatar is String && avatar.isEmpty)) {
    return const AssetImage('assets/default_avatar.avif'); 
  }

  if (avatar is String && avatar.startsWith('data:image/')) {
    try {
      final String base64Data = avatar.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    } catch (e) {
      debugPrint("Failed to decode base64 image: $e");
    }
  }

  if (avatar is String && Uri.tryParse(avatar)?.hasAbsolutePath == true) {
    return NetworkImage(avatar);
  }

  return const AssetImage('assets/default_avatar.avif');
}