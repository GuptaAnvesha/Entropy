import 'package:flutter/material.dart';
import '../widgets/components.dart';

class LoggingPage extends StatefulWidget {
  const LoggingPage({super.key});

  @override
  State<LoggingPage> createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  double _focusLevel = 5;
  double _energyLevel = 5;
  String _selectedMood = '😐';
  String _selectedReason = '';

  final List<String> _reasons = ['Distracted', 'Bored', 'Too Hard', 'No Clarity', 'Done'];
  final List<String> _moods = ['😭', '😔', '😐', '🙂', '🚀'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Log Session', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Selector Mock
            Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                const Text('14:00 - 15:30', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                  child: const Text('1h 30m', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                )
              ],
            ),
            
            const SizedBox(height: 32),
            TextField(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
              decoration: InputDecoration(
                hintText: 'What did you work on?',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 20),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary)),
              ),
            ),
            
            const SizedBox(height: 48),
            _buildSliderParams('Focus level', _focusLevel, (v) => setState(() => _focusLevel = v)),
            const SizedBox(height: 32),
            _buildSliderParams('Energy level', _energyLevel, (v) => setState(() => _energyLevel = v)),
            
            const SizedBox(height: 48),
            const Text('State of mind', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _moods.map((emo) => EmojiSelector(
                emoji: emo, 
                isSelected: _selectedMood == emo, 
                onTap: () => setState(() => _selectedMood = emo)
              )).toList(),
            ),
            
            const SizedBox(height: 48),
            const Text('Why did you stop?', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _reasons.map((r) => PillChip(
                label: r, 
                isSelected: _selectedReason == r, 
                onTap: () => setState(() => _selectedReason = r)
              )).toList(),
            ),
            
            const SizedBox(height: 56),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.background,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Save Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSliderParams(String title, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            Text(value.toInt().toString(), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: AppColors.textPrimary,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.textPrimary,
            overlayColor: AppColors.textPrimary.withOpacity(0.1),
          ),
          child: Slider(value: value, min: 1, max: 10, divisions: 9, onChanged: onChanged),
        ),
      ],
    );
  }
}
