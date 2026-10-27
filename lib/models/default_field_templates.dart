import 'field_definition.dart';

class DefaultFieldTemplate {
  const DefaultFieldTemplate({
    required this.label,
    required this.type,
    this.defaultValue,
    this.sampleValues = const [],
    this.numberMin = 0,
    this.numberMax = 100,
  });

  final String label;
  final FieldType type;
  final String? defaultValue;
  final List<String> sampleValues;
  final double numberMin;
  final double numberMax;

  static DefaultFieldTemplate? findByLabel(String label) {
    final lower = label.toLowerCase();
    for (final t in catalog) {
      if (t.label.toLowerCase() == lower) return t;
    }
    return null;
  }

  static const catalog = [
    DefaultFieldTemplate(
      label: 'Problem',
      type: FieldType.text,
      sampleValues: [
        // Computer hardware & operating system
        'Blue screen of death',
        'Operating system fails to boot',
        'Computer running very slow',
        'Disk space almost full',
        'CPU overheating, fan very loud',
        'Random shutdowns under load',
        'SSD not detected after update',
        'RAM errors causing crashes',
        'Screen flickering or no display',
        'Keyboard or mouse not responding',
        'USB port not detecting devices',
        'Windows update stuck',
        // Networking
        'Wi-Fi keeps disconnecting',
        'No internet connection',
        'Network printer not reachable',
        // Computer science
        'Application crashes on startup',
        'Memory leak in application',
        'Database query too slow',
        'Compilation error in build',
        'Recursion causing stack overflow',
        'Version control merge conflict',
        'Antivirus blocking an application',
        // Office software
        'Excel formula returns an error',
        'Large Excel file very slow to open',
        'Word document corrupted',
        'Outlook not syncing email',
        'PowerPoint crashes on export',
        'OneDrive sync stuck',
        'Teams or Zoom login failure',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Solution',
      type: FieldType.text,
      sampleValues: [
        'Reinstalled the operating system',
        'Replaced the faulty RAM module',
        'Freed disk space and cleaned temp files',
        'Cleaned CPU cooler and reapplied thermal paste',
        'Replaced the failing power supply',
        'Updated the storage controller driver',
        'Ran memory diagnostics and replaced the DIMM',
        'Replaced the display cable',
        'Replaced keyboard and mouse',
        'Updated the USB controller driver',
        'Reset Windows Update components',
        'Rebooted the wireless router',
        'Reconfigured printer network settings',
        'Updated the network adapter driver',
        'Reinstalled the application',
        'Fixed the memory leak and redeployed',
        'Added a database index and optimized the query',
        'Fixed the compile error and rebuilt the project',
        'Rewrote the recursive function using iteration',
        'Resolved the merge conflict and merged the branch',
        'Added an antivirus exception rule',
        'Corrected the Excel formula',
        'Split the workbook and optimized formulas',
        'Repaired the corrupted Word document',
        'Rebuilt the Outlook profile',
        'Exported the slides to PDF instead',
        'Paused and resumed OneDrive sync',
        'Cleared the app cache and signed in again',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Machine',
      type: FieldType.text,
      defaultValue: 'PC-01',
      sampleValues: [
        'PC-01',
        'PC-02',
        'LAPTOP-14',
        'WORKSTATION-03',
        'SERVER-01',
        'PRINTER-02',
        'ROUTER-01',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Technician',
      type: FieldType.text,
      defaultValue: 'Ahmed',
      sampleValues: ['Ahmed', 'Ali', 'Sara', 'Omar', 'Hassan'],
    ),
    DefaultFieldTemplate(
      label: 'Priority',
      type: FieldType.text,
      defaultValue: 'Medium',
      sampleValues: ['Low', 'Medium', 'High', 'Critical'],
    ),
    DefaultFieldTemplate(
      label: 'Root Cause',
      type: FieldType.text,
      sampleValues: [
        'Failing hardware component',
        'Outdated device driver',
        'Insufficient disk space',
        'Software bug',
        'Corrupted system file',
        'Malware infection',
        'Misconfigured network settings',
        'Damaged document file',
        'Overheating due to dust',
        'Incompatible software update',
        'User error',
        'Weak Wi-Fi signal',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Status',
      type: FieldType.text,
      defaultValue: 'Open',
      sampleValues: ['Open', 'In progress', 'Completed', 'On hold'],
    ),
    DefaultFieldTemplate(
      label: 'Spare Part',
      type: FieldType.text,
      sampleValues: [
        'RAM 8GB DDR4',
        'SSD 512GB',
        'Power supply 500W',
        'CPU cooler fan',
        'Thermal paste',
        'HDMI cable',
        'USB hub',
        'Keyboard',
        'Mouse',
        'Wi-Fi adapter',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Downtime (hours)',
      type: FieldType.number,
      defaultValue: '0',
      numberMin: 0.5,
      numberMax: 48,
    ),
    DefaultFieldTemplate(
      label: 'Work Order',
      type: FieldType.text,
      sampleValues: ['WO-1001', 'WO-1002', 'WO-1003', 'WO-2048', 'WO-3055'],
    ),
    DefaultFieldTemplate(label: 'Completed Date', type: FieldType.date),
  ];
}
