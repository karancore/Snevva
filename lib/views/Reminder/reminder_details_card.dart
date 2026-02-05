import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';

import '../../consts/colors.dart';

class ReminderDetailsCard extends StatefulWidget {
  final ReminderPayloadModel reminder;
  final int index; // used when rendering a list to uniquely identify the card
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReminderDetailsCard({
    super.key,
    required this.reminder,
    required this.index,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ReminderDetailsCard> createState() => _ReminderDetailsCardState();
}

class _ReminderDetailsCardState extends State<ReminderDetailsCard>
    with SingleTickerProviderStateMixin {
  bool expanded = false;

  String _formatDateTimeString(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat.jm().format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _pluralize(String unit, int value) => value == 1 ? unit : '${unit}s';

  Widget _buildHeader() {
    return Row(
      children: [
        // Leading icon placeholder — you can replace with category icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              widget.reminder.category.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.reminder.title ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.reminder.category ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: () {
            setState(() => expanded = !expanded);
          },
          icon: Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.grey.shade700,
          ),
        ),
        IconButton(
          onPressed: widget.onEdit,
          icon: Icon(Icons.edit, color: Colors.grey.shade700),
        ),
        IconButton(
          onPressed: widget.onDelete,
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
        ),
      ],
    );
  }

  Widget _buildDivider() => const Divider(height: 16, thickness: 1);

  Widget _buildMedicineDetails() {
    final medName = widget.reminder.medicineName;
    final notes = widget.reminder.notes;
    final dosageValue = widget.reminder.dosage?.value.toString();
    final dosageUnit = widget.reminder.dosage?.unit.toString();
    final medicineType = widget.reminder.medicineType;

    final timesList = widget.reminder.customReminder?.timesPerDay?.list ?? [];
    final timesCount =
        int.tryParse(
          widget.reminder.customReminder?.timesPerDay?.count?.toString() ?? '',
        ) ??
        timesList.length;

    final everyXHours = widget.reminder.customReminder?.everyXHours?.hours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medName != null && medName.isNotEmpty)
          _infoRow('Medicine', medName),

        if (medicineType != null) _infoRow('Medicine Type', medicineType),
        if (dosageValue != null) _infoRow('Dosage', "$dosageValue $dosageUnit"),
        if (notes != null && notes.isNotEmpty) _infoRow('Notes', notes),

        if (timesList.isNotEmpty)
          _infoRow(
            'Schedule',
            timesList.map((t) => _formatDateTimeString(t)).join(' • '),
          )
        else if (everyXHours != null)
          _infoRow(
            'Interval',
            'Every $everyXHours ${_pluralize("hour", everyXHours)}',
          ),
        if (widget.reminder.remindBefore != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _infoRow(
              'Reminder before',
              '${widget.reminder.remindBefore?.time ?? ""} ${widget.reminder.remindBefore?.unit ?? ""}',
            ),
          ),
      ],
    );
  }

  Widget _buildWaterDetails() {
    final custom = widget.reminder.customReminder;
    final isInterval = custom?.everyXHours != null;
    final isTimes =
        custom?.timesPerDay != null &&
        (custom!.timesPerDay!.count?.toString().isNotEmpty ?? false);

    final intervalHours = custom?.everyXHours?.hours;
    final startHour = widget.reminder.startWaterTime;

    final endHour = widget.reminder.endWaterTime;

    final timesCount =
        int.tryParse(custom?.timesPerDay?.count?.toString() ?? '0') ?? 0;
    final timesList = custom?.timesPerDay?.list ?? [];
    final notes = widget.reminder.notes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isInterval) _infoRow('Mode', 'Interval based'),
        if (intervalHours != null)
          _infoRow(
            'Interval',
            'Every $intervalHours ${_pluralize("hour", intervalHours)} between $startHour and $endHour',
          ),
        if (isTimes) _infoRow('Mode', 'Times per day'),
        if (timesCount > 0)
          _infoRow(
            'Times per day',
            '$timesCount time${timesCount > 1 ? 's' : ''} between $startHour and $endHour',
          ),
        if (timesList.isNotEmpty)
          _infoRow(
            'Times',
            timesList.map((t) => _formatDateTimeString(t)).join(' • '),
          ),
        if (notes != null && notes.isNotEmpty) _infoRow('Notes', notes),
      ],
    );
  }

  Widget _buildMealDetails() {
    final timesList = widget.reminder.customReminder?.timesPerDay?.list ?? [];
    final notes = widget.reminder.notes;
    print("notes $notes");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timesList.isNotEmpty)
          _infoRow(
            'Time',
            timesList.map((t) => _formatDateTimeString(t)).join(' • '),
          ),
        if (notes != null && notes.isNotEmpty) _infoRow('Notes', notes),
      ],
    );
  }

  Widget _buildEventDetails() {
    final timesList = widget.reminder.customReminder?.timesPerDay?.list ?? [];
    final notes = widget.reminder.notes;
    final remindBefore = widget.reminder.remindBefore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timesList.isNotEmpty)
          _infoRow(
            'Time',
            timesList.map((t) => _formatDateTimeString(t)).join(' • '),
          ),
        if (notes != null && notes.isNotEmpty) _infoRow('Notes', notes),
        if (remindBefore != null)
          _infoRow(
            'Remind before',
            '${remindBefore.time} ${remindBefore.unit}',
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: grey.withOpacity(0.5), width: 1.0),
      ),
      elevation: 0,

      color: isDarkMode ? darkGray : white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            //_buildHeader(),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //_buildDivider(),
                  if (widget.reminder.category == 'Medicine')
                    _buildMedicineDetails(),
                  if (widget.reminder.category == 'Water') _buildWaterDetails(),
                  if (widget.reminder.category == 'Meal') _buildMealDetails(),
                  if (widget.reminder.category == 'Event') _buildEventDetails(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
