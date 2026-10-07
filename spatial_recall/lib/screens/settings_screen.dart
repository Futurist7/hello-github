import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../state/app_state.dart';

/// Keep in sync with `version:` in pubspec.yaml.
const appVersion = '1.0.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('This erases your levels, scores, XP, streaks and daily results. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.wrong),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await AppScope.read(context).resetProgress();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress reset.')));
  }

  void _showDoc(BuildContext context, String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(body, style: const TextStyle(height: 1.4))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Section(
            children: [
              SwitchListTile(
                title: const Text('Sound'),
                secondary: const Icon(Icons.volume_up_rounded),
                value: s.sound,
                onChanged: (v) => state.updateSettings(s.copyWith(sound: v)),
              ),
              SwitchListTile(
                title: const Text('Haptics'),
                secondary: const Icon(Icons.vibration_rounded),
                value: s.haptics,
                onChanged: (v) => state.updateSettings(s.copyWith(haptics: v)),
              ),
              SwitchListTile(
                title: const Text('Reduced motion'),
                subtitle: const Text('Fewer animations. Gameplay is unchanged.'),
                secondary: const Icon(Icons.animation_rounded),
                value: s.reducedMotion,
                onChanged: (v) => state.updateSettings(s.copyWith(reducedMotion: v)),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.fromLTRB(8, 24, 8, 8), child: Caption('Game')),
          _Section(
            children: [
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded, color: AppColors.wrong),
                title: const Text('Reset progress', style: TextStyle(color: AppColors.wrong)),
                onTap: () => _confirmReset(context),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.fromLTRB(8, 24, 8, 8), child: Caption('About')),
          _Section(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                onTap: () => _showDoc(context, 'Privacy Policy', _privacy),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms'),
                onTap: () => _showDoc(context, 'Terms', _terms),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Version'),
                trailing: Text(
                  appVersion,
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );
}

const _privacy = '''Spatial Recall works entirely offline.

• No account or sign-in is required.
• No personal data is collected, transmitted or shared.
• Your progress, scores and settings are stored only on this device and are removed when you uninstall the app or use "Reset progress".
• The app does not use analytics, advertising or tracking.

If this changes in a future version, this policy will be updated before the change ships.''';

const _terms = '''Spatial Recall is provided "as is" for personal entertainment.

• Your progress is stored locally; we cannot recover it if it is lost or reset.
• The game is not a medical or diagnostic tool and makes no claims about cognitive improvement.
• You may not redistribute or resell the app.''';
