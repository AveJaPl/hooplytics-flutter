import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../services/voice_controller.dart';

class ShootingSessionScreen extends StatefulWidget {
  const ShootingSessionScreen({super.key});

  @override
  State<ShootingSessionScreen> createState() => _ShootingSessionScreenState();
}

class _ShootingSessionScreenState extends State<ShootingSessionScreen> {
  final VoiceController _voiceController = VoiceController();
  bool _isSpeechInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final available = await _voiceController.initSpeech();
    setState(() {
      _isSpeechInitialized = available;
    });
  }

  void _handleVoiceCommand(String text) {
    print('Recognized: $text');
    if (text.contains('punkt') ||
        text.contains('trafiony') ||
        text.contains('trafienie')) {
      context.read<SessionProvider>().addShot(true);
    } else if (text.contains('pudło') ||
        text.contains('spudłowany') ||
        text.contains('chybiony')) {
      context.read<SessionProvider>().addShot(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final session = sessionProvider.currentSession;

    if (session == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('${session.range} - ${session.position}'),
        actions: [
          IconButton(
            onPressed: () {
              sessionProvider.endSession();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _buildStatsDisplay(
              session.makes,
              session.attempts,
              session.percentage,
            ),
          ),
          Expanded(flex: 3, child: _buildControls(sessionProvider)),
          _buildVoiceIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatsDisplay(int makes, int attempts, double percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 84,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$makes / $attempts',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(SessionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildShotButton(true, provider)),
              const SizedBox(width: 16),
              Expanded(child: _buildShotButton(false, provider)),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'LUB UŻYJ KOMEND GŁOSOWYCH',
            style: TextStyle(
              color: Colors.grey,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _buildMicButton(),
          const SizedBox(height: 8),
          const Text(
            '"Punkt" / "Pudło"',
            style: TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShotButton(bool isMake, SessionProvider provider) {
    return ElevatedButton(
      onPressed: () => provider.addShot(isMake),
      style: ElevatedButton.styleFrom(
        backgroundColor: isMake
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        foregroundColor: isMake ? Colors.green : Colors.red,
        padding: const EdgeInsets.symmetric(vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isMake ? Colors.green : Colors.red, width: 2),
        ),
      ),
      child: Icon(isMake ? Icons.add_circle : Icons.remove_circle, size: 40),
    );
  }

  Widget _buildMicButton() {
    bool isListening = _voiceController.isListening;
    return GestureDetector(
      onTap: () {
        if (isListening) {
          _voiceController.stopListening();
        } else {
          _voiceController.startListening(_handleVoiceCommand);
        }
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isListening
              ? Theme.of(context).colorScheme.primary
              : Colors.white10,
          shape: BoxShape.circle,
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : [],
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          size: 40,
          color: isListening
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildVoiceIndicator() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        _isSpeechInitialized
            ? 'Sterowanie głosowe gotowe'
            : 'Inicjalizacja mikrofonu...',
        style: TextStyle(
          color: _isSpeechInitialized
              ? Colors.green.withOpacity(0.7)
              : Colors.orange,
        ),
      ),
    );
  }
}
