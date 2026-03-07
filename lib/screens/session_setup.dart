import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import 'shooting_session.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  String selectedRange = 'Trójki';
  String selectedPosition = 'Szczyt';

  final List<String> ranges = ['Rzuty wolne', 'Półdystans', 'Trójki'];
  final List<String> positions = [
    'Szczyt',
    'Skrzydło Lewe',
    'Skrzydło Prawe',
    'Róg Lewy',
    'Róg Prawy',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nowa Sesja')),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Dystans'),
            const SizedBox(height: 12),
            _buildSelectionGrid(ranges, selectedRange, (val) {
              setState(() => selectedRange = val);
            }),
            const SizedBox(height: 32),
            _buildSectionTitle('Pozycja'),
            const SizedBox(height: 12),
            _buildSelectionGrid(positions, selectedPosition, (val) {
              setState(() => selectedPosition = val);
            }),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                context.read<SessionProvider>().startNewSession(
                  selectedPosition,
                  selectedRange,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShootingSessionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ROZPOCZNIJ TRENING',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSelectionGrid(
    List<String> items,
    String selected,
    Function(String) onSelect,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = item == selected;
        return InkWell(
          onTap: () => onSelect(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white24,
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
