import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/services/notification_preferences_store.dart';
import '../../core/services/user_profile_store.dart';
import '../../core/widgets/common/confirm_dialog.dart';
import '../../core/widgets/common/white_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Student';
  String _userEmail = '';
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final displayName = user?.displayName?.trim();
    _userEmail = email;
    _userName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (email.isEmpty ? 'Student' : email.split('@').first);
    _nameController.text = _userName;

    if (user != null) {
      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(_onUserProfileSnapshot);
    }
  }

  void _onUserProfileSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!mounted || _isEditingName) return;
    final data = snap.data();
    final fromFirestore = (data?['username'] as String?)?.trim();
    if (fromFirestore == null || fromFirestore.isEmpty) return;
    if (fromFirestore == _userName) return;
    setState(() {
      _userName = fromFirestore;
      _nameController.text = _userName;
    });
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    showConfirmDialog(
      context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmText: 'Log out',
      destructive: true,
    ).then((confirmed) async {
      if (!confirmed) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.authChecker,
        (route) => false,
      );
    });
  }

  Future<void> _handleEditName() async {
    if (_isEditingName) {
      final nextName = _nameController.text.trim().isEmpty
          ? 'Student'
          : _nameController.text.trim();
      setState(() {
        _userName = nextName;
        _isEditingName = false;
      });
      // Firestore queues offline; Auth profile update requires network.
      await UserProfileStore.updateUsernameForCurrentUser(nextName);
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(nextName);
      } catch (_) {
        // Offline or transient failure — username still syncs via Firestore.
      }
    } else {
      setState(() {
        _isEditingName = true;
        _nameController.text = _userName;
      });
    }
  }

  Future<void> _updatePrefs(NotificationPreferences next) async {
    try {
      await updateNotificationPreferences(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder preferences updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Check internet and try again.')),
      );
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information Section
            _buildUserInfoSection(textTheme),
            const SizedBox(height: AppSpacing.md),

            // Account Management Section
            _buildSectionHeader(textTheme, 'Account Management'),
            const SizedBox(height: AppSpacing.sm),
            WhiteCard(
              child: _buildMenuItem(
                context,
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.changePassword);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ValueListenableBuilder<NotificationPreferences>(
              valueListenable: notificationPreferencesNotifier,
              builder: (context, prefs, _) {
                return WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMenuSwitchRow(
                        context,
                        icon: Icons.notifications_outlined,
                        title: 'Task Reminders',
                        value: prefs.enabled,
                        onChanged: (value) {
                          _updatePrefs(prefs.copyWith(enabled: value));
                        },
                      ),
                      if (prefs.enabled) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Reminder Lead Time',
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: prefs.leadTimeMinutes,
                          items: const [
                            DropdownMenuItem(
                              value: 60,
                              child: Text('1 hour before'),
                            ),
                            DropdownMenuItem(
                              value: 45,
                              child: Text('45 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text('30 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text('15 minutes before'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            _updatePrefs(
                              prefs.copyWith(leadTimeMinutes: value),
                            );
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Academic Management Section
            _buildSectionHeader(textTheme, 'Academic Management'),
            const SizedBox(height: AppSpacing.sm),
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
        _isEditingName
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    child: TextField(
                      controller: _nameController,
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      autofocus: true,
                      onSubmitted: (_) => _handleEditName(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _handleEditName,
                    iconSize: 24,
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userName,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
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
            color: appPrimarySwatch.shade600,
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
        color: appPrimarySwatch.shade900,
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
                color: colorScheme.primary.withValues(alpha: 0.08),
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
            const Icon(
              Icons.chevron_right,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSwitchRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
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
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
