import 'package:flutter/material.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggregate Telemetry', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: theme.colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Drift Index & Entropy', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Evaluating systemic behavioral degradation over time.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),
            
            // Mock Chart Area
            Container(
              height: 240,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Friction vs Protocol Adherence', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
                      Icon(Icons.stacked_line_chart, color: theme.colorScheme.primary, size: 18),
                    ],
                  ),
                  const Spacer(),
                  // Overlay mock graph indicating inverse correlation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDoubleBar(30, 80, theme), // Low friction, high adherence
                      _buildDoubleBar(40, 70, theme),
                      _buildDoubleBar(50, 60, theme),
                      _buildDoubleBar(80, 20, theme), // High friction, low adherence (crisis)
                      _buildDoubleBar(60, 40, theme),
                      _buildDoubleBar(30, 90, theme),
                      _buildDoubleBar(20, 95, theme), // Peak flow
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      Text('E-6', style: TextStyle(fontSize: 10, color: Colors.white38)),
                      Text('E-5', style: TextStyle(fontSize: 10, color: Colors.white38)),
                      Text('E-4', style: TextStyle(fontSize: 10, color: Colors.white38)),
                      Text('E-3', style: TextStyle(fontSize: 10, color: Colors.white38)),
                      Text('E-2', style: TextStyle(fontSize: 10, color: Colors.white38)),
                      Text('E-1', style: TextStyle(fontSize: 10, color: Colors.white38)),
                      Text('Now', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text('Telemetry Averages', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildMetricCard('Drift Index', '1.4σ', Icons.radar, Colors.redAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard('Protocol Fidelity', '88%', Icons.security, Colors.greenAccent)),
              ],
            ),
            
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text('Entropy Synthesis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Historical data mapping shows acute system erosion occurring precisely around Epoch-3. The catalyst correlates directly with contextual switching. Implementing a strict "Do Not Disturb" block during early operating hours should stabilize the drift index.',
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleBar(double frictionFactor, double adherenceFactor, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Top cap for friction
        Container(
          width: 12,
          height: frictionFactor,
          decoration: BoxDecoration(
            color: Colors.pinkAccent.withOpacity(0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 2),
        // Base bar for adherence
        Container(
          width: 12,
          height: adherenceFactor,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
