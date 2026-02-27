import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../mock/mock_academic_session.dart';
import '../../models/academic_session.dart';
import '../../utils/date_time_format.dart';

class AcademicSessionSetupBottomSheet extends StatefulWidget {
  const AcademicSessionSetupBottomSheet({super.key});

  static Future<AcademicSession?> show(BuildContext context) {
    return showModalBottomSheet<AcademicSession>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AcademicSessionSetupBottomSheet(),
    );
  }

  @override
  State<AcademicSessionSetupBottomSheet> createState() =>
      _AcademicSessionSetupBottomSheetState();
}

class _AcademicSessionSetupBottomSheetState
    extends State<AcademicSessionSetupBottomSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateError;

  Future<void> _pickStartDate() async {
    final baseTheme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(data: baseTheme, child: child!),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = null;
      }
      _dateError = null;
    });
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      setState(() {
        _dateError = 'Please select a start date first.';
      });
      return;
    }

    final baseTheme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(data: baseTheme, child: child!),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      _dateError = null;
    });
  }

  void _handleSave() {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _dateError = 'Start date and end date are required.';
      });
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      setState(() {
        _dateError = 'End date must be on or after the start date.';
      });
      return;
    }

    final session = AcademicSession.fromDates(
      startDate: _startDate!,
      endDate: _endDate!,
    );
    setCurrentAcademicSession(session);
    Navigator.pop(context, session);
  }

  @override
  Widget build(BuildContext context) {
    final generatedName = _startDate != null && _endDate != null
        ? '${_startDate!.year}/${_endDate!.year}'
        : null;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Up Academic Session',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Session name is auto-generated from the selected years.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (generatedName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Session: $generatedName',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start date',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickStartDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _startDate == null
                              ? 'Select date'
                              : formatDateDdMmYyyy(_startDate!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'End date',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickEndDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _endDate == null
                              ? 'Select date'
                              : formatDateDdMmYyyy(_endDate!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_dateError != null) ...[
            const SizedBox(height: 6),
            Text(
              _dateError!,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSave,
              child: const Text('Save session'),
            ),
          ),
        ],
      ),
    );
  }
}

