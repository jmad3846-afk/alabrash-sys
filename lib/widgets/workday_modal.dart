import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../core/database/erp_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import 'currency_selector.dart';

class WorkdayModal extends StatefulWidget {
  const WorkdayModal({super.key});

  @override
  State<WorkdayModal> createState() => _WorkdayModalState();
}

class _WorkdayModalState extends State<WorkdayModal> {
  DateTime? selectedTechnicianDate;
  String? selectedTechnicianId;
  String technicianRateType = 'حساب يومية';
  String workCurrency = AppCurrency.usd;
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);
    final weekStart = erp.activeWorkweekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final technicians = erp.staffList
        .where((staff) => staff.category == 'معلمين')
        .toList();
    selectedTechnicianId ??= technicians.firstOrNull?.id;
    selectedTechnicianDate ??= weekStart;

    return Dialog(
      child: SizedBox(
        width: 1240,
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 12, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'تحديد عمالة',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'إغلاق',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'الأسبوع: ${_formatDate(weekStart)} — ${_formatDate(weekEnd)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            erp.openNextWorkweek();
                            setState(() {
                              selectedTechnicianDate = erp.activeWorkweekStart;
                            });
                          },
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('مسح الجدول وفتح أسبوع جديد'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'يمسح هذا الإجراء عرض الحضور للأسبوع الحالي بفتح أسبوع جديد، مع إبقاء الأجور المكتسبة في السجلات المالية.',
                    style: TextStyle(color: AppColors.brandSecondaryText),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(text: 'العمال'),
                  Tab(text: 'المعلمون'),
                  Tab(text: 'الإداريون'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildAttendanceSection(erp, 'عمال', weekStart),
                    _buildTechnicianSection(erp, technicians, weekStart),
                    _buildAttendanceSection(erp, 'إداريين', weekStart),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(
    ERPProvider erp,
    String category,
    DateTime weekStart,
  ) {
    final people = erp.staffList
        .where((staff) => staff.category == category)
        .toList();
    final types = erp.staffTypes
        .where((type) => type.category == category)
        .toList();

    if (people.isEmpty) {
      return Center(
        child: Text(
          types.isEmpty
              ? 'أضف نوعاً وظيفياً ثم سجّل $category.'
              : 'لا يوجد $category مسجلون.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'حدد الحضور لكل يوم. تُسجّل أجرة النوع اليومية تلقائياً عند التأشير.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...types.map((type) {
            final typedPeople = people
                .where((staff) => staff.typeId == type.id)
                .toList();
            if (typedPeople.isEmpty) return const SizedBox.shrink();
            return _buildTypeAttendanceTable(
              erp,
              type,
              typedPeople,
              weekStart,
              category,
            );
          }),
          ...people
              .where((staff) => !types.any((type) => type.id == staff.typeId))
              .map(
                (staff) => Card(
                  child: ListTile(
                    title: Text(staff.name),
                    subtitle: const Text(
                      'هذا الموظف غير مرتبط بنوع وأجر يومي.',
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTypeAttendanceTable(
    ERPProvider erp,
    StaffTypeModel type,
    List<StaffModel> people,
    DateTime weekStart,
    String category,
  ) {
    final dates = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    ).where(
      (date) =>
          (category != 'عمال' && category != 'إداريين') ||
          date.weekday != DateTime.friday,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${type.name} — الأجر اليومي: ${type.dailyRate.fmt}\$',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('العامل')),
                  ...dates.map(
                    (date) => DataColumn(
                      label: SizedBox(
                        width: 100,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_weekdayName(date.weekday)),
                            Text(_formatDate(date)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                rows: people
                    .map(
                      (staff) => DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 170,
                              child: Text(
                                staff.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          ...dates.map((date) {
                            final checked = erp.staffAttendance.any(
                              (entry) =>
                                  entry.staffId == staff.id &&
                                  _sameDate(entry.date, date),
                            );
                            return DataCell(
                              SizedBox(
                                width: 100,
                                child: Checkbox(
                                  value: checked,
                                  onChanged: (value) {
                                    final saved = erp.setStaffAttendance(
                                      staff: staff,
                                      date: date,
                                      present: value ?? false,
                                    );
                                    if (!saved && mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'تعذر تعديل الحضور. تحقق من نوع الموظف، أو من عدم تسديد أجر هذا اليوم مسبقاً.',
                                          ),
                                          backgroundColor:
                                              AppColors.dangerWaste,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianSection(
    ERPProvider erp,
    List<StaffModel> technicians,
    DateTime weekStart,
  ) {
    final technician = technicians
        .where((staff) => staff.id == selectedTechnicianId)
        .firstOrNull;
    final weekEnd = weekStart.add(const Duration(days: 7));
    final entries =
        erp.workdayEntries
            .where(
              (entry) =>
                  (entry.staffId == selectedTechnicianId ||
                      (entry.staffId.isEmpty &&
                          technician != null &&
                          entry.staffNames.contains(technician.name))) &&
                  !entry.date.isBefore(weekStart) &&
                  entry.date.isBefore(weekEnd),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'أضف يوم عمل لكل معلم، وحدد طريقة الأجر والمبلغ المتفق عليه لذلك اليوم.',
          ),
          const SizedBox(height: 12),
          if (technicians.isEmpty)
            const Text('لا يوجد معلمون مسجلون.')
          else ...[
            DropdownButtonFormField<String>(
              initialValue:
                  technicians.any((staff) => staff.id == selectedTechnicianId)
                  ? selectedTechnicianId
                  : null,
              decoration: const InputDecoration(labelText: 'المعلم'),
              items: technicians
                  .map(
                    (staff) => DropdownMenuItem(
                      value: staff.id,
                      child: Text(staff.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => selectedTechnicianId = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedTechnicianDate ?? weekStart,
                        firstDate: weekStart,
                        lastDate: weekStart.add(const Duration(days: 6)),
                      );
                      if (picked != null) {
                        setState(() => selectedTechnicianDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      'التاريخ: ${_formatDate(selectedTechnicianDate ?? weekStart)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'حساب يومية',
                        label: Text('أجر يومي'),
                      ),
                      ButtonSegment(
                        value: 'حساب مقطوع',
                        label: Text('مقطوع / عقد ثابت'),
                      ),
                    ],
                    selected: {technicianRateType},
                    onSelectionChanged: (selected) =>
                        setState(() => technicianRateType = selected.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المتفق عليه لليوم',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CurrencySelector(
                    value: workCurrency,
                    dense: true,
                    onChanged: (value) => setState(() => workCurrency = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'وصف إنجاز العمل (اختياري)',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton.icon(
                onPressed: technician == null
                    ? null
                    : () => _saveTechnicianDay(erp, technician),
                icon: const Icon(Icons.add),
                label: const Text('إضافة يوم عمل للمعلم'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'أيام العمل المسجلة هذا الأسبوع (${entries.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('لا توجد أيام عمل مسجلة لهذا المعلم هذا الأسبوع.'),
              ),
            ...entries.map(
              (entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.engineering_outlined),
                  title: Text(
                    '${_formatDate(entry.date)} — ${entry.agreedAmountPerPerson.fmt}${AppCurrency.symbol(entry.currency)}',
                  ),
                  subtitle: Text(
                    '${entry.rateType} • ${entry.workDescription}',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _saveTechnicianDay(ERPProvider erp, StaffModel technician) {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final date = selectedTechnicianDate ?? erp.activeWorkweekStart;
    final saved = erp.recordTechnicianWorkday(
      WorkdayEntryModel(
        id: 'tech_workday_${DateTime.now().microsecondsSinceEpoch}',
        date: date,
        staffNames: [technician.name],
        staffId: technician.id,
        workDescription: descriptionController.text.trim(),
        rateType: technicianRateType,
        agreedAmountPerPerson: amount,
        currency: workCurrency,
      ),
    );
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل مبلغاً صحيحاً واختر معلماً صالحاً.'),
          backgroundColor: AppColors.dangerWaste,
        ),
      );
      return;
    }
    amountController.clear();
    descriptionController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل يوم العمل ومستحقات المعلم.'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  static bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _formatDate(DateTime date) =>
      intl.DateFormat('yyyy-MM-dd').format(date);

  static String _weekdayName(int weekday) => const [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ][weekday - 1];
}
