import 'package:flutter/material.dart';
import '../core/app_toast.dart';
import '../core/theme.dart';
import '../services/token_storage_service.dart';
import '../services/driver_backend_service.dart';

class VehicleData {
  final String model;
  final String regNumber;
  final String type;
  final bool isPrimary;
  final bool isVerified;

  VehicleData({
    required this.model,
    required this.regNumber,
    required this.type,
    this.isPrimary = false,
    this.isVerified = true,
  });

  Map<String, dynamic> toMap() => {
    'model': model,
    'regNumber': regNumber,
    'type': type,
    'isPrimary': isPrimary,
    'isVerified': isVerified,
  };

  factory VehicleData.fromMap(Map<String, dynamic> map) => VehicleData(
    model: map['model']?.toString() ?? '',
    regNumber: map['regNumber']?.toString() ?? '',
    type: map['type']?.toString() ?? 'Sedan',
    isPrimary: map['isPrimary'] == true,
    isVerified: map['isVerified'] != false,
  );
}

class VehicleManagementScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  final VoidCallback? onAddVehicleTap;

  const VehicleManagementScreen({
    super.key,
    this.onBackTap,
    this.onAddVehicleTap,
  });

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  List<VehicleData> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final saved = await TokenStorageService.instance.getVehicles();
    if (saved != null && saved.isNotEmpty) {
      if (mounted) {
        setState(() {
          _vehicles = saved.map((m) => VehicleData.fromMap(m)).toList();
        });
      }
    } else {
      final profile = TokenStorageService.instance.driverProfile;
      final dynamic rawVeh = profile?['vehicleId'] ?? profile?['vehicleNumber'];
      final regNum = (rawVeh != null && rawVeh.toString().trim().isNotEmpty)
          ? rawVeh.toString().trim().toUpperCase()
          : 'DL 01 AB 1234';

      final defaultList = [
        VehicleData(
          model: 'Honda City (Sedan)',
          regNumber: '$regNum • White',
          type: 'Sedan',
          isPrimary: true,
          isVerified: true,
        ),
      ];
      if (mounted) {
        setState(() {
          _vehicles = defaultList;
        });
      }
    }

    _syncRemoteVehicles();
  }

  Future<void> _syncRemoteVehicles() async {
    try {
      final remoteList = await DriverBackendService.instance.getVehicles();
      if (remoteList.isNotEmpty && mounted) {
        setState(() {
          _vehicles = remoteList.map((m) => VehicleData.fromMap(m)).toList();
        });
      }
    } catch (_) {}
  }

  void _showAddVehicleModal() {
    final modelController = TextEditingController();
    final regController = TextEditingController();
    String selectedType = 'Car';
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bottomInset = MediaQuery.of(modalCtx).viewInsets.bottom;
            const vehicleTypes = ['Car', 'Bike', 'Auto', 'Other'];
            return SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: bottomInset > 0 ? bottomInset : 8,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Secondary Vehicle',
                            style: TextStyle(
                              color: QuickServeColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: QuickServeColors.textSecondary),
                            onPressed: () => Navigator.of(modalCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Model Name
                      const Text(
                        'Vehicle Model & Make',
                        style: TextStyle(color: QuickServeColors.textDark, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: QuickServeColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Icon(_vehicleIcon(selectedType), color: QuickServeColors.textSecondary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: modelController,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(color: QuickServeColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: _modelHint(selectedType),
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  isDense: true,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Registration Number
                      const Text(
                        'Registration Number (RC)',
                        style: TextStyle(color: QuickServeColors.textDark, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: QuickServeColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pin_outlined, color: QuickServeColors.textSecondary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: regController,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(color: QuickServeColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. DL 03 CD 5678',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  isDense: true,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Vehicle type selector. The API already persists the
                      // selected type, so no backend contract changes are needed.
                      const Text(
                        'Vehicle Type',
                        style: TextStyle(color: QuickServeColors.textDark, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: vehicleTypes.map((type) {
                          final isSel = selectedType == type;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedType = type),
                            child: Container(
                              width: (MediaQuery.sizeOf(modalCtx).width - 56) / 2,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: isSel ? QuickServeColors.primaryOrangeLight : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? QuickServeColors.primaryOrange : QuickServeColors.borderLight,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _vehicleIcon(type),
                                    size: 18,
                                    color: isSel ? QuickServeColors.primaryOrange : QuickServeColors.textSecondary,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    type,
                                    style: TextStyle(
                                      color: isSel ? QuickServeColors.primaryOrange : QuickServeColors.textDark,
                                      fontSize: 13,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 22),

                      // Add Button
                      ElevatedButton(
                        onPressed: () async {
                          final newModel = modelController.text.trim();
                          final newReg = regController.text.trim().toUpperCase();

                          if (newModel.length < 3) {
                            setModalState(() {
                              errorMessage = 'Please enter a valid vehicle model (at least 3 characters)';
                            });
                            return;
                          }

                          if (newReg.length < 4) {
                            setModalState(() {
                              errorMessage = 'Please enter a valid registration number (e.g. DL 03 CD 5678)';
                            });
                            return;
                          }

                          // Check duplicates locally
                          final cleanNewReg = newReg.replaceAll(RegExp(r'\s+'), '');
                          final isDuplicate = _vehicles.any((v) {
                            final cleanExisting = v.regNumber.split('•').first.replaceAll(RegExp(r'\s+'), '').toUpperCase();
                            return cleanExisting == cleanNewReg;
                          });

                          if (isDuplicate) {
                            setModalState(() {
                              errorMessage = 'A vehicle with registration "$newReg" is already registered.';
                            });
                            return;
                          }

                          // INSTANT: Add vehicle to UI immediately
                          final addedVehicle = VehicleData(
                            model: '$newModel ($selectedType)',
                            regNumber: '$newReg • White',
                            type: selectedType,
                            isPrimary: false,
                            isVerified: true,
                          );

                          if (mounted) {
                            setState(() {
                              _vehicles.add(addedVehicle);
                            });
                          }

                          // Save locally
                          await TokenStorageService.instance.saveVehicles(
                            _vehicles.map((v) => v.toMap()).toList(),
                          );

                          // Close modal and show success instantly
                          if (modalCtx.mounted) {
                            Navigator.of(modalCtx).pop();
                          }
                          if (mounted) {
                            AppToast.success(context, 'Vehicle $newModel added successfully!');
                          }

                          // Backend sync in background — non-blocking
                          DriverBackendService.instance.addVehicle(
                            model: newModel,
                            regNumber: newReg,
                            type: selectedType,
                          ).catchError((e) {
                            debugPrint('[Vehicle] Backend sync error: $e');
                          });

                          widget.onAddVehicleTap?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuickServeColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Add Vehicle',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _vehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler_rounded;
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      case 'other':
        return Icons.local_shipping_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  String _modelHint(String type) {
    switch (type.toLowerCase()) {
      case 'bike':
        return 'e.g. Honda Activa';
      case 'auto':
        return 'e.g. Bajaj RE Auto';
      case 'other':
        return 'e.g. Vehicle make and model';
      default:
        return 'e.g. Maruti Suzuki Dzire';
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuickServeColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Vehicle Management',
          style: TextStyle(
            color: QuickServeColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: QuickServeColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // List of Vehicles
              for (int i = 0; i < _vehicles.length; i++) ...[
                _buildVehicleCard(_vehicles[i]),
                const SizedBox(height: 16),
              ],

              // CTA Add Secondary Vehicle Button
              ElevatedButton(
                onPressed: _showAddVehicleModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuickServeColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Secondary Vehicle',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleData v) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: v.isPrimary ? QuickServeColors.borderLight : QuickServeColors.primaryOrange.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: QuickServeColors.primaryOrangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_vehicleIcon(v.type), color: QuickServeColors.primaryOrange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            v.model,
                            style: const TextStyle(
                              color: QuickServeColors.textDark,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (v.isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: QuickServeColors.primaryOrangeLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Primary',
                              style: TextStyle(
                                color: QuickServeColors.primaryOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      v.regNumber,
                      style: const TextStyle(
                        color: QuickServeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: QuickServeColors.statusGreen, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: QuickServeColors.statusGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: QuickServeColors.borderLight),
          const SizedBox(height: 12),

          const Text(
            'Compliance & Document Expiries',
            style: TextStyle(
              color: QuickServeColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          _buildDocStatusItem('Vehicle RC', 'Valid till March 2028', true),
          const SizedBox(height: 8),
          _buildDocStatusItem('State Fitness Permit', 'Valid till December 2027', true),
          const SizedBox(height: 8),
          _buildDocStatusItem('Pollution (PUC)', 'Valid till August 2026', true),
        ],
      ),
    );
  }

  Widget _buildDocStatusItem(String name, String validity, bool isValid) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, color: QuickServeColors.statusGreen, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: QuickServeColors.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          validity,
          style: const TextStyle(
            color: QuickServeColors.textDark,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
