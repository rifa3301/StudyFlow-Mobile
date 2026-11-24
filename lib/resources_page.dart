import 'dart:async';

import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';

class ResourcesPage extends StatefulWidget {
  final String token;

  const ResourcesPage({
    super.key,
    required this.token,
  });

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _resources = [];

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resources = await ApiService.getResources(
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        _resources = resources;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _value(
      Map<String, dynamic> resource,
      String snakeCase,
      String camelCase, {
        String fallback = '',
      }) {
    return (resource[snakeCase] ?? resource[camelCase] ?? fallback)
        .toString();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _openAddResourceForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => _AddResourceSheet(token: widget.token),
    );

    if (result == true && mounted) {
      _loadResources();
    }
  }

  Future<void> _submitRating(
      int resourceId,
      int rating,
      ) async {
    try {
      await ApiService.rateResource(
        token: widget.token,
        resourceId: resourceId,
        rating: rating,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your rating has been saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadResources();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadResources,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                sliver: SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                sliver: SliverToBoxAdapter(
                  child: _buildIntroCard(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                sliver: SliverToBoxAdapter(
                  child: _buildResourceContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STUDY MATERIALS',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Resources',
                style: AppTextStyles.heading,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadResources,
          tooltip: 'Refresh resources',
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your learning library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Collect useful study materials and share resources with others.',
                  style: TextStyle(
                    color: Color(0xFFD7DEED),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 15),
                FilledButton.icon(
                  onPressed: _openAddResourceForm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add resource',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.menu_book_rounded,
            color: AppColors.accent,
            size: 47,
          ),
        ],
      ),
    );
  }

  Widget _buildResourceContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(45),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildMessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load resources',
        message: _errorMessage!,
        buttonText: 'Try again',
        onPressed: _loadResources,
      );
    }

    if (_resources.isEmpty) {
      return _buildMessageCard(
        icon: Icons.library_books_outlined,
        title: 'Your library is empty',
        message:
        'Add your first study resource to start building your learning library.',
        buttonText: 'Add your first resource',
        onPressed: _openAddResourceForm,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'All resources',
                style: AppTextStyles.title,
              ),
            ),
            Text(
              '${_resources.length} items',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: 15),
        ..._resources.map(_buildResourceCard),
      ],
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    final title = _value(
      resource,
      'title',
      'title',
      fallback: 'Untitled resource',
    );

    final description = _value(
      resource,
      'description',
      'description',
      fallback: 'No description provided.',
    );

    final category = _value(
      resource,
      'category',
      'category',
      fallback: 'General',
    );

    final type = _value(
      resource,
      'resource_type',
      'resourceType',
      fallback: 'Resource',
    );

    final visibility = _value(
      resource,
      'visibility',
      'visibility',
      fallback: 'public',
    );

    final resourceId = _integer(
      resource['resource_id'] ?? resource['resourceId'],
    );

    final averageRating = _number(
      resource['average_rating'] ?? resource['averageRating'],
    );

    final ratingCount = _integer(
      resource['rating_count'] ?? resource['ratingCount'],
    );

    final userRating = _integer(
      resource['user_rating'] ?? resource['userRating'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _resourceIcon(type),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _visibilityBadge(visibility),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),

          if (type.toLowerCase() == 'video') ...[
            const SizedBox(height: 15),
            _EmbeddedYoutubeVideo(
              url: _value(
                resource,
                'resource_url',
                'resourceUrl',
              ),
            ),
          ],

          const SizedBox(height: 13),
          Row(
            children: [
              _typeBadge(type),
              const Spacer(),
              const Icon(
                Icons.star_rounded,
                color: AppColors.warning,
                size: 17,
              ),
              const SizedBox(width: 4),
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($ratingCount)',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(
              height: 1,
              color: AppColors.divider,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  userRating > 0 ? 'Your rating' : 'Rate this resource',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildRatingStars(
                resourceId: resourceId,
                currentRating: userRating,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars({
    required int resourceId,
    required int currentRating,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        final selected = value <= currentRating;

        return IconButton(
          onPressed: resourceId <= 0
              ? null
              : () => _submitRating(resourceId, value),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(
            minWidth: 27,
            minHeight: 32,
          ),
          tooltip: '$value star${value == 1 ? '' : 's'}',
          icon: Icon(
            selected ? Icons.star_rounded : Icons.star_outline_rounded,
            color: AppColors.warning,
            size: 23,
          ),
        );
      }),
    );
  }

  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _visibilityBadge(String visibility) {
    final isPrivate = visibility.toLowerCase() == 'private';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isPrivate
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPrivate ? 'Private' : 'Public',
        style: TextStyle(
          color: isPrivate ? AppColors.warning : AppColors.success,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData _resourceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'website':
        return Icons.language_rounded;
      case 'notes':
        return Icons.edit_note_rounded;
      case 'article':
        return Icons.article_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.secondary,
            size: 35,
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: AppTextStyles.title.copyWith(fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _AddResourceSheet extends StatefulWidget {
  final String token;

  const _AddResourceSheet({
    required this.token,
  });

  @override
  State<_AddResourceSheet> createState() => _AddResourceSheetState();
}

class _AddResourceSheetState extends State<_AddResourceSheet> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _urlController = TextEditingController();

  String _resourceType = 'Article';
  String _visibility = 'public';

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveResource() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ApiService.createResource(
        token: widget.token,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        resourceType: _resourceType,
        resourceUrl: _urlController.text.trim(),
        visibility: _visibility,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a resource URL';
    }

    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a valid URL starting with http:// or https://';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 13, 22, 25),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Add a resource',
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: 6),
                Text(
                  'Save a useful study material to your library.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                _buildLabel('Resource title'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 200,
                  decoration: _inputDecoration(
                    hint: 'e.g. Data Structures lecture notes',
                    icon: Icons.title_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildLabel('Description'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hint: 'What is this resource about?',
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLabel('Category / Subject'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    hint: 'e.g. Data Structures',
                    icon: Icons.category_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildLabel('Resource type'),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  initialValue: _resourceType,
                  decoration: _inputDecoration(
                    hint: 'Choose a type',
                    icon: Icons.library_books_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Article',
                      child: Text('Article'),
                    ),
                    DropdownMenuItem(
                      value: 'Video',
                      child: Text('Video'),
                    ),
                    DropdownMenuItem(
                      value: 'PDF',
                      child: Text('PDF'),
                    ),
                    DropdownMenuItem(
                      value: 'Website',
                      child: Text('Website'),
                    ),
                    DropdownMenuItem(
                      value: 'Notes',
                      child: Text('Notes'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _resourceType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildLabel('Resource URL'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: _inputDecoration(
                    hint: 'https://example.com/resource',
                    icon: Icons.link_rounded,
                  ),
                  validator: _validateUrl,
                ),
                const SizedBox(height: 12),
                _buildLabel('Visibility'),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  initialValue: _visibility,
                  decoration: _inputDecoration(
                    hint: 'Choose visibility',
                    icon: Icons.visibility_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'public',
                      child: Text('Public — visible to everyone'),
                    ),
                    DropdownMenuItem(
                      value: 'private',
                      child: Text('Private — only visible to you'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _visibility = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 23),
                SizedBox(
                  width: double.infinity,
                  height: 51,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveResource,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 21,
                      width: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Save resource',
                      style: AppTextStyles.button,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(
        color: AppColors.secondary.withValues(alpha: 0.75),
      ),
      prefixIcon: Icon(
        icon,
        size: 19,
        color: AppColors.secondary,
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.4,
        ),
      ),
    );
  }
}

class _EmbeddedYoutubeVideo extends StatefulWidget {
  final String url;

  const _EmbeddedYoutubeVideo({
    required this.url,
  });

  @override
  State<_EmbeddedYoutubeVideo> createState() =>
      _EmbeddedYoutubeVideoState();
}

class _EmbeddedYoutubeVideoState
    extends State<_EmbeddedYoutubeVideo> {
  YoutubePlayerController? _controller;

  String? get _videoId {
    return YoutubePlayerController.convertUrlToId(
      widget.url.trim(),
    );
  }

  void _startVideo() {
    final videoId = _videoId;

    if (videoId == null || videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is not a valid YouTube video URL.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
        ),
      );
    });
  }

  @override
  void dispose() {
    final controller = _controller;

    if (controller != null) {
      unawaited(controller.close());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: YoutubePlayer(
          controller: controller,
          aspectRatio: 16 / 9,
          autoFullScreen: true,
          keepAlive: false,
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }

    return Material(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: _startVideo,
        borderRadius: BorderRadius.circular(13),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 53,
                height: 53,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Play video inside StudyFlow',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}