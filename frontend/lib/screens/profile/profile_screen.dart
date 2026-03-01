import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/widgets/common/white_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Alex';
  final String _userEmail = 'alex123@student.usm.my';
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = _userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            child: const Text(
              'Log out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEditName() {
    if (_isEditingName) {
      // Save the name
      setState(() {
        _userName = _nameController.text.trim().isEmpty
            ? 'Alex'
            : _nameController.text.trim();
        _isEditingName = false;
      });
    } else {
      // Start editing
      setState(() {
        _isEditingName = true;
        _nameController.text = _userName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Log out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information Section
            _buildUserInfoSection(textTheme),
            const SizedBox(height: AppSpacing.lg),

            // Account Management Section
            _buildSectionHeader(textTheme, 'Account Management'),
            const SizedBox(height: AppSpacing.md),
            WhiteCard(
              child: _buildMenuItem(
                context,
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () {
                  // TODO: Navigate to change password screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Change password (mock)')),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Academic Management Section
            _buildSectionHeader(textTheme, 'Academic Management'),
            const SizedBox(height: AppSpacing.md),
            WhiteCard(
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Academic Sessions',
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.academicSessions);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 0.5),
                  const SizedBox(height: AppSpacing.md),
                  _buildMenuItem(
                    context,
                    icon: Icons.book_outlined,
                    title: 'Courses',
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.courses);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 0.5),
                  const SizedBox(height: AppSpacing.md),
                  _buildMenuItem(
                    context,
                    icon: Icons.access_time_outlined,
                    title: 'Timetables',
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.timetables);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isEditingName
                ? SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _nameController,
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      autofocus: true,
                      onSubmitted: (_) => _handleEditName(),
                    ),
                  )
                : Text(
                    _userName,
                    style: textTheme.titleLarge,
                  ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: Icon(_isEditingName ? Icons.check : Icons.edit_outlined),
              onPressed: _handleEditName,
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _userEmail,
          style: textTheme.bodyMedium?.copyWith(
            color: AppPrimarySwatch.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(TextTheme textTheme, String title) {
    return Text(
      title,
      style: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppPrimarySwatch.shade900,
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}
