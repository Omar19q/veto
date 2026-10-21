import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

class AdminAuditLogPanel extends StatefulWidget {
  const AdminAuditLogPanel({super.key});

  @override
  State<AdminAuditLogPanel> createState() => _AdminAuditLogPanelState();
}

class _AdminAuditLogPanelState extends State<AdminAuditLogPanel> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final logs = await SupabaseService.instance.getAuditLogs(limit: 100);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _actionColor(String action) {
    if (action.contains('create') || action.contains('add')) {
      return Color(0xFF4CAF50);
    }
    if (action.contains('delete') || action.contains('block')) {
      return Color(0xFFEF5350);
    }
    if (action.contains('update') || action.contains('edit')) {
      return AdminTheme.goldDark;
    }
    return AdminTheme.muted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'سجل التغييرات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : _logs.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد سجلات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.muted,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final log = _logs[i];
                    final action = log['action'] as String? ?? '';
                    final entityType = log['entity_type'] as String? ?? '';
                    final createdAt = log['created_at'] as String?;
                    return Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminTheme.borderSoft),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: _actionColor(action),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _actionColor(action),
                                  ),
                                ),
                                Text(
                                  entityType,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: AdminTheme.muted,
                                  ),
                                ),
                                if (log['details'] != null)
                                  Text(
                                    log['details'].toString(),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: AdminTheme.muted,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDate(createdAt),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: AdminTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
