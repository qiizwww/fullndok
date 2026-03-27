import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/panen_provider.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedKandang = 'semua';
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    _selectedStartDate = DateTime.now().subtract(const Duration(days: 7));
    _selectedEndDate = DateTime.now();
    _lastRefreshAt = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade100,
              Colors.amber.shade100,
              Colors.greenAccent.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Filter Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Tanggal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectStartDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedStartDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_selectedStartDate!)
                                        : 'Mulai',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'sd',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: _selectEndDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedEndDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_selectedEndDate!)
                                        : 'Akhir',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Filter Kandang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedKandang,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'semua',
                          child: Text('Semua Kandang'),
                        ),
                        DropdownMenuItem(
                          value: 'kandang1',
                          child: Text('Kandang 1'),
                        ),
                        DropdownMenuItem(
                          value: 'kandang2',
                          child: Text('Kandang 2'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedKandang = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _lastRefreshAt != null
                              ? 'Update: ${DateFormat('dd/MM/yyyy HH:mm').format(_lastRefreshAt!)}'
                              : 'Belum pernah refresh',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _handleRefresh,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(child: _buildRiwayatList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiwayatList() {
    final panenProvider = context.watch<PanenProvider>();

    final panens = _getFilteredPanens(panenProvider);
    final groupedPanens = <DateTime, List<dynamic>>{};
    for (final panen in panens) {
      final key = DateTime(
        panen.tanggalPanen.year,
        panen.tanggalPanen.month,
        panen.tanggalPanen.day,
      );
      groupedPanens.putIfAbsent(key, () => []).add(panen);
    }
    final sortedDates = groupedPanens.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final key in sortedDates) {
      groupedPanens[key]!
          .sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));
    }

    final totalTelur =
        panens.fold<int>(0, (sum, p) => sum + (p.jumlahTelur as int));

    final listChildren = <Widget>[
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade300, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.shade300.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Produksi',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalTelur',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'telur',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const Text('🥚', style: TextStyle(fontSize: 48)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${panens.length} pencatatan panen',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Detail Panen Per Hari',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 12),
    ];

    if (panens.isEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📭', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada data panen',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      for (final date in sortedDates) {
        final items = groupedPanens[date]!;
        final dailyTotal =
            items.fold<int>(0, (sum, p) => sum + (p.jumlahTelur as int));

        listChildren.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMMM yyyy').format(date),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$dailyTotal telur',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...items.map(
                    (panen) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  panen.kandangNama,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${panen.jam} • ${(panen.jenisPanen ?? 'manual').toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${panen.jumlahTelur} 🥚',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: listChildren,
      ),
    );
  }

  List<dynamic> _getFilteredPanens(PanenProvider panenProvider) {
    final allPanens = List<dynamic>.from(panenProvider.panens);
    final startDate = _selectedStartDate;
    final endDate = _selectedEndDate;

    final startBoundary = startDate != null
        ? DateTime(startDate.year, startDate.month, startDate.day)
        : null;
    final endBoundary = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999)
        : null;

    final filtered = allPanens.where((panen) {
      final inDateRange = (startBoundary == null ||
              !panen.tanggalPanen.isBefore(startBoundary)) &&
          (endBoundary == null || !panen.tanggalPanen.isAfter(endBoundary));

      if (!inDateRange) return false;

      if (_selectedKandang == 'semua') return true;

      final kandangIdLower = panen.kandangId.toString().toLowerCase();
      final kandangNamaLower = panen.kandangNama.toString().toLowerCase();
      final normalized =
          '$kandangIdLower $kandangNamaLower'.replaceAll('_', '');
      return normalized.contains(_selectedKandang);
    }).toList();

    filtered.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));
    return filtered;
  }

  Future<void> _handleRefresh() async {
    final panenProvider = context.read<PanenProvider>();
    await panenProvider.loadTodaySnapshots();
    await panenProvider.restorePanenHistoryFromFirebase();
    if (!mounted) return;
    setState(() {
      _lastRefreshAt = DateTime.now();
    });
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }
}
