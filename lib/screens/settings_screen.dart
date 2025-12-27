import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talk2me_flutter_app/main.dart';

import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = 'Loading...';
  ThemeMode _selectedThemeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    // If using a theme provider, initialize _selectedThemeMode from it:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeModeFromMain = Talk2MeApp.of(context).themeMode;
      if (mounted) {
        setState(() {
          _selectedThemeMode = themeModeFromMain;
        });
      }
    });
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion =
              '${packageInfo.version} (Build ${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Error loading version';
        });
      }
    }
  }

  Future<void> _showThemeChooserDialog() async {
    final theme = Theme.of(context);
    ThemeMode? newThemeMode = await showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Choose Theme',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                ThemeMode.values.map((mode) {
                  return RadioListTile<ThemeMode>(
                    title: Text(
                      mode.name[0].toUpperCase() + mode.name.substring(1),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: mode,
                    groupValue: _selectedThemeMode, // Use the state variable
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        Navigator.of(dialogContext).pop(value);
                      }
                    },
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: theme.hintColor)),
            ),
          ],
        );
      },
    );

    if (newThemeMode != null) {
      setState(() {
        Talk2MeApp.of(context).changeTheme(newThemeMode);
        _selectedThemeMode = newThemeMode;
      });
    }
  }

  Future<void> _logout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirm Logout',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: theme.hintColor)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text(
                'Logout',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      try {
        // Update user's online status before signing out
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
                'isOnline': false,
                'lastSeen': FieldValue.serverTimestamp(),
              });
        }
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // This would come from your theme provider
    // final themeProvider = Provider.of<ThemeProvider>(context);
    // _selectedThemeMode = themeProvider.themeMode;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: <Widget>[
          _buildSectionTitle(context, 'Appearance'),
          _buildSettingsListItem(
            context: context,
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle:
                _selectedThemeMode.name[0].toUpperCase() +
                _selectedThemeMode.name.substring(1),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.hintColor,
            ),
            onTap: _showThemeChooserDialog,
          ),
          const Divider(height: 20, indent: 16, endIndent: 16),
          _buildSectionTitle(context, 'Account'),
          _buildSettingsListItem(
            context: context,
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.hintColor,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit Profile (Not Implemented)')),
              );
            },
          ),
          _buildSettingsListItem(
            context: context,
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.hintColor,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Change Password (Not Implemented)'),
                ),
              );
            },
          ),

          const Divider(height: 20, indent: 16, endIndent: 16),
          _buildSectionTitle(context, 'Notifications'),
          _buildSettingsListItem(
            context: context,
            icon: Icons.notifications_none_rounded,
            title: 'Push Notifications',
            trailing: Switch(
              value: true, // Placeholder, manage with state/provider
              onChanged: (bool value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Push Notifications ${value ? "Enabled" : "Disabled"} (Conceptual)',
                    ),
                  ),
                );
              },
              activeThumbColor: theme.colorScheme.primary,
            ),
            onTap: () {
              /* Can also toggle here or navigate */
            },
          ),
          Opacity(
            opacity: 0.5,
            child: _buildSettingsListItem(
              context: context,
              icon: Icons.volume_up_outlined,
              title: 'In-app Sounds',
              trailing: Switch(
                value: false, // Placeholder
                onChanged: (bool value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('This feature is coming soon (Conceptual)'),
                    ),
                  );
                },
                activeThumbColor: theme.colorScheme.primary,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('This feature is coming soon (Conceptual)'),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 20, indent: 16, endIndent: 16),
          _buildSectionTitle(context, 'About'),
          _buildSettingsListItem(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: _appVersion,
          ),
          _buildSettingsListItem(
            context: context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.hintColor,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terms of Service (Not Implemented)'),
                ),
              );
            },
          ),
          _buildSettingsListItem(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.hintColor,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy Policy (Not Implemented)'),
                ),
              );
            },
          ),
          const Divider(height: 30, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: ElevatedButton.icon(
              icon: Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.onError,
              ),
              label: Text(
                'Logout',
                style: TextStyle(
                  color: theme.colorScheme.onError,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    theme
                        .colorScheme
                        .errorContainer, // Or theme.colorScheme.error for more emphasis
                foregroundColor: theme.colorScheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _logout,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary, // Or theme.hintColor
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsListItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor, // Not typically needed if using theme.iconTheme.color
  }) {
    final theme = Theme.of(context);
    return Material(
      color:
          Colors
              .transparent, // Use transparent for InkWell ripple on theme background
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor ?? theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle:
            subtitle != null
                ? Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                )
                : null,
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ), // For InkWell shape
      ),
    );
  }
}
