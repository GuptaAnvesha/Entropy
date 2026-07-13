import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../auth_provider.dart';
import '../widgets/components.dart';

class LoggingPage extends StatefulWidget {
  final double durationMinutes;
  final DateTime startTime;
  final String sessionId;

  const LoggingPage({
    super.key,
    required this.durationMinutes,
    required this.startTime,
    required this.sessionId,
  });

  @override
  State<LoggingPage> createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  double _focusLevel = 5;
  double _energyLevel = 5;
  String _selectedMood = '😐';
  String _selectedReason = '';
  bool _isSaving = false;

  final List<String> _reasons = ['Distracted', 'Bored', 'Too Hard', 'No Clarity', 'Done'];
  final List<String> _moods = ['😭', '😔', '😐', '🙂', '🚀'];
  
  final TextEditingController _taskNameController = TextEditingController();

  @override
  void dispose() {
    _taskNameController.dispose();
    super.dispose();
  }

  void _saveLog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.currentUser?.uid ?? '';
    
    if (uid.isEmpty || widget.sessionId.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final endTime = DateTime.now();

    try {
      // 1. Update Firestore session doc
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .doc(widget.sessionId)
          .update({
        'taskName': _taskNameController.text.trim().isEmpty 
            ? 'Focus Session' 
            : _taskNameController.text.trim(),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': widget.durationMinutes,
        'focusLevel': _focusLevel.toInt(),
        'energyLevel': _energyLevel.toInt(),
        'mood': _selectedMood,
        'stopReason': _selectedReason,
        'status': 'completed',
      });

      // 2. Call cloud function agent asynchronously
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('analyzeDriftSession');
        await callable.call({
          'uid': uid,
          'sessionId': widget.sessionId,
        });
      } catch (e) {
        debugPrint("Failed to call analyzeDriftSession Cloud Function: $e");
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving log: $e"),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final endTime = DateTime.now();
    final startStr = DateFormat('HH:mm').format(widget.startTime);
    final endStr = DateFormat('HH:mm').format(endTime);
    
    String durationStr;
    if (widget.durationMinutes < 1.0) {
      durationStr = '${(widget.durationMinutes * 60).toInt()}s';
    } else if (widget.durationMinutes < 60) {
      durationStr = '${widget.durationMinutes.toInt()}m';
    } else {
      durationStr = '${(widget.durationMinutes / 60).floor()}h ${(widget.durationMinutes % 60).toInt()}m';
    }

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
            Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text('$startStr - $endStr', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                  child: Text(durationStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                )
              ],
            ),
            
            const SizedBox(height: 32),
            TextField(
              controller: _taskNameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
              decoration: const InputDecoration(
                hintText: 'What did you work on?',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 20),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary)),
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
              child: _isSaving
                  ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.background,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saveLog,
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
