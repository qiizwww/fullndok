import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/panen_scheduler.dart';

/// Debug Screen untuk testing Panen Scheduler
/// Menampilkan jadwal otomatis dan button trigger manual
class PanenDebugScreen extends StatefulWidget {
  const PanenDebugScreen({super.key});

  @override
  State<PanenDebugScreen> createState() => _PanenDebugScreenState();
}

class _PanenDebugScreenState extends State<PanenDebugScreen> {
  Map<String, String>? _nextSchedules;
  Map<String, dynamic>? _todaySnapshot;
  bool _isLoading = false;
  String? _lastAction;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final schedules = PanenScheduler.getNextScheduledTimes();
      final snapshot = await PanenScheduler.getTodaySnapshot();

      setState(() {
        _nextSchedules = schedules;
        _todaySnapshot = snapshot;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _triggerPanenPagi() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Panen Pagi';
    });

    try {
      final result = await PanenScheduler.triggerPanenPagiManual();
      await _loadData(); // Reload snapshot

      setState(() {
        _lastResult = result['success']
            ? '✅ ${result['message']}'
            : '❌ ${result['message']}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerPanenSore() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Panen Sore';
    });

    try {
      final result = await PanenScheduler.triggerPanenSoreManual();
      await _loadData(); // Reload snapshot

      setState(() {
        _lastResult = result['success']
            ? '✅ ${result['message']}'
            : '❌ ${result['message']}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Panen Scheduler'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  _buildInfoCard(),
                  const SizedBox(height: 16),

                  // Jadwal Otomatis Card
                  _buildScheduleCard(),
                  const SizedBox(height: 16),

                  // Manual Trigger Buttons
                  _buildManualTriggerSection(),
                  const SizedBox(height: 16),

                  // Snapshot Hari Ini
                  _buildSnapshotCard(),
                  const SizedBox(height: 16),

                  // Last Action Result
                  if (_lastResult != null) _buildLastActionCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Text(
                  'Informasi Debug',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Screen ini untuk mengecek apakah sistem panen otomatis berjalan dengan baik.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Jadwal Otomatis: Pagi 09:00, Sore 15:00\n'
              '• Button Manual: Test simpan riwayat panen\n'
              '• Snapshot: Lihat data yang tersimpan hari ini',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange[800]),
                const SizedBox(width: 8),
                Text(
                  'Jadwal Otomatis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_nextSchedules != null) ...[
              _buildScheduleItem(
                'Panen Pagi',
                _nextSchedules!['pagi']!,
                Icons.wb_sunny,
                Colors.amber,
              ),
              const Divider(height: 24),
              _buildScheduleItem(
                'Panen Sore',
                _nextSchedules!['sore']!,
                Icons.wb_twilight,
                Colors.orange,
              ),
            ] else
              const Text('Memuat jadwal...'),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(
    String title,
    String schedule,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Jadwal berikutnya:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                schedule,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualTriggerSection() {
    return Card(
      elevation: 3,
      color: Colors.teal[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app, color: Colors.teal[800]),
                const SizedBox(width: 8),
                Text(
                  'Trigger Manual (Debug)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Klik button untuk test simpan riwayat panen secara manual:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _triggerPanenPagi,
                    icon: const Icon(Icons.wb_sunny),
                    label: const Text('Simpan Panen Pagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _triggerPanenSore,
                    icon: const Icon(Icons.wb_twilight),
                    label: const Text('Simpan Panen Sore'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.data_object, color: Colors.purple[800]),
                const SizedBox(width: 8),
                Text(
                  'Snapshot Hari Ini',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (_todaySnapshot != null) ...[
              if (_todaySnapshot!.containsKey('pagi')) ...[
                _buildSnapshotSection('Pagi', _todaySnapshot!['pagi']),
                const SizedBox(height: 12),
              ],
              if (_todaySnapshot!.containsKey('sore')) ...[
                _buildSnapshotSection('Sore', _todaySnapshot!['sore']),
              ],
              if (!_todaySnapshot!.containsKey('pagi') &&
                  !_todaySnapshot!.containsKey('sore'))
                const Text('Belum ada data snapshot hari ini'),
            ] else
              const Text('Belum ada snapshot hari ini'),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotSection(String title, dynamic data) {
    if (data == null) return const SizedBox();

    final Map<String, dynamic> snapshotData = Map<String, dynamic>.from(data);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...snapshotData.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLastActionCard() {
    return Card(
      color: _lastResult!.startsWith('✅') ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _lastResult!.startsWith('✅')
                      ? Icons.check_circle
                      : Icons.error,
                  color:
                      _lastResult!.startsWith('✅') ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hasil Terakhir',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Aksi: $_lastAction',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _lastResult!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
