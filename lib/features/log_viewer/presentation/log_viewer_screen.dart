import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/logger/black_box_logger.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final BlackBoxLogger _logger = BlackBoxLogger();
  List<LogEntry> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _logger.getAllLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('TERMİNAL GÜNLÜĞÜ'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child:
                      Text('Günlük boş', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return _buildTerminalLog(log);
                  },
                ),
    );
  }

  Widget _buildTerminalLog(LogEntry log) {
    final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
    Color statusColor;
    if (log.status == 'SUCCESS') {
      statusColor = Colors.greenAccent;
    } else if (log.status == 'FAILED') {
      statusColor = Colors.redAccent;
    } else {
      statusColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('[$timeStr]',
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                    color: statusColor.withAlpha(51), // withOpacity(0.2)
                    borderRadius: BorderRadius.circular(2)),
                child: Text(log.operation,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              ),
              const Spacer(),
              if (log.deviceIp != null)
                Text(log.deviceIp!,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          Text(log.details,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          if (log.command != null && log.command!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('RUNNING:',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              color: Colors.black,
              child: Text(
                '\$ ${log.command}',
                style: const TextStyle(
                    color: Colors.lightGreenAccent,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
          ],
          if (log.output != null && log.output!.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('OUTPUT:',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              color: Colors.black,
              child: SelectableText(
                log.output!,
                style: TextStyle(
                  color:
                      log.status == 'SUCCESS' ? Colors.white : Colors.redAccent,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
