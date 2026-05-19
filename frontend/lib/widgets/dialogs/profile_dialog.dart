import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../provider/profile_provider.dart';
import '../../utils/image_utils.dart';

const double _profileAvatarRadius = 60.0;

class MyProfileDialog extends StatefulWidget {
  final String? initialAvatarUrl;

  const MyProfileDialog({super.key, this.initialAvatarUrl});

  /// Static shortcut helper method to open the profile configuration dialog layer cleanly.
  static Future<void> show(BuildContext context, {String? initialAvatarUrl}) {
    return showDialog(
      context: context,
      builder: (context) => MyProfileDialog(initialAvatarUrl: initialAvatarUrl),
    );
  }

  @override
  State<MyProfileDialog> createState() => _MyProfileDialogState();
}

class _MyProfileDialogState extends State<MyProfileDialog> {
  late TextEditingController nameController;
  ProfileProvider? _profileProvider;

  @override
  void initState() {
    super.initState();
    
    // Bind context to read local provider values during bootstrap sequence
    _profileProvider = context.read<ProfileProvider>();
    
    // Initialize controller with current cache values or fall back to an empty string
    nameController = TextEditingController(text: _profileProvider?.name ?? '');
    
    // Attach an active lifecycle listener to update the text field as soon as 
    // async network queries resolve data back from the backend service.
    _profileProvider?.addListener(_onProfileStateChanged);
    
    // Trigger localized async network sequence to fetch fresh user metrics
    _profileProvider?.loadMyProfile();
  }

  /// Synchronizes the TextEditingController string text when the async provider state modifies.
  void _onProfileStateChanged() {
    if (_profileProvider == null || !mounted) return;
    
    // Only overwrite the controller text if the user hasn't typed anything new yet
    final updatedName = _profileProvider!.name ?? '';
    if (nameController.text != updatedName && updatedName.isNotEmpty) {
      setState(() {
        nameController.text = updatedName;
      });
    }
  }

  @override
  void dispose() {
    // Tear down listener hooks to prevent memory leaks or async execution ghost frames
    _profileProvider?.removeListener(_onProfileStateChanged);
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch structural adjustments targeting the user metadata layer
    final profileProvider = context.watch<ProfileProvider>();
    final avatarUrl = profileProvider.avatar ?? widget.initialAvatarUrl;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: const Text(
        'My profile',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatarHeader(profileProvider, avatarUrl),
            const SizedBox(height: 16),
            _buildNameField(),
            const SizedBox(height: 12),
            _buildEmailDisplay(profileProvider.email),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// Builds the gradient header section containing the profile picture avatar container.
  Widget _buildAvatarHeader(ProfileProvider provider, String? avatar) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 60),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDBCEE1), Color(0xFFC6AFC3)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickAndUploadImage(provider),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: _profileAvatarRadius,
                  backgroundColor: Colors.white,
                  backgroundImage: getAvatarProvider(avatar),
                ),
                Positioned(right: 0, bottom: 0, child: _buildEditCircle()),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('Tap to change photo', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  /// Captures an image artifact from the device hardware gallery, serializes it to base64 data, 
  /// and updates the ProfileProvider state.
  Future<void> _pickAndUploadImage(ProfileProvider provider) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compresses file sizes to match payload network constraints
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final dataUrl =
        'data:${picked.mimeType ?? "image/jpeg"};base64,${base64Encode(bytes)}';
    await provider.updateAvatar(dataUrl);
  }

  /// Renders the small floating edit icon button nested over the avatar container frame.
  Widget _buildEditCircle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Color(0xFF91BDE4),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.edit, size: 14, color: Colors.white),
    );
  }

  /// Renders the text field component alongside transactional safe state modification tracking flags.
  Widget _buildNameField() {
    final provider = context.read<ProfileProvider>();
    final currentName = provider.name ?? '';
    final isChanged =
        nameController.text.trim() != currentName &&
        nameController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Display name',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          onChanged: (_) => setState(() {}), // Force contextual state evaluation ticks to evaluate change triggers
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        
        // Contextual save row toggled into visibility parameters when edit mismatches occur
        if (isChanged)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Name changed',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.save, size: 13),
                    label: const Text('Save', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await provider.updateDisplayName(
                        nameController.text.trim(),
                      );
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Displays the serialized text account email address associated with this identity instance.
  Widget _buildEmailDisplay(String? email) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(email ?? 'No email')),
        ],
      ),
    );
  }

  /// Renders standard dialog navigation execution dismiss keys.
  Widget _buildActionButtons() {
    return SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    );
  }
}